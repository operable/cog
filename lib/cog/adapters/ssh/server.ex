defmodule Cog.Adapters.SSH.Server do
  import Cog.Adapters.SSH, only: [authenticate: 2]
  import Cog.Helpers, only: [ensure_integer: 1]

  alias Cog.Adapters.SSH.Shell

  require Logger

  use GenServer

  defstruct listener: nil, mq_conn: nil, bot_username: nil, command_prefix: nil

  @server_name :ssh_server
  @adapter_name "ssh"
  @adapter_topic "/bot/adapters/ssh/+"
  @gc_interval 300000 # five minutes

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: @server_name)
  end

  def init([]) do
    command_prefix = Application.get_env(:cog, :command_prefix)
    ssh_config = Application.get_env(:cog, Cog.Adapters.SSH)
    bot_username = fetch_required(ssh_config, :bot_username)
    port = ensure_integer(fetch_required(ssh_config, :port))

    options = [
      system_dir: fetch_required(ssh_config, :host_key_dir),
    ] |> ensure_charlist_values

    :ets.new(@server_name, [:bag, :named_table])
    {:ok, mq_conn} = Carrier.Messaging.Connection.connect()
    Carrier.Messaging.Connection.subscribe(mq_conn, @adapter_topic)

    state = %__MODULE__{mq_conn: mq_conn, bot_username: bot_username, command_prefix: command_prefix}

    Process.send_after(@server_name, :gc_room_pids, @gc_interval)
    start_ssh(port, options, state)
  end

  defp start_ssh(port, options, state) do
    Logger.debug("Starting SSH server on port #{port}")
    case :ssh.start do
      :ok ->
        fun_opts = [
          shell: fn(user, peer) -> start_cog(to_string(user), peer, state) end,
          pwdfun: fn(user, password) -> authenticate(to_string(user), to_string(password)) end,
          disconnectfun: fn(_reason) -> send(self, :gc_room_pids) end
        ]

        {:ok, listener} = :ssh.daemon(port, Keyword.merge(options, fun_opts))
        {:ok, %{ state | listener: listener }}
      error ->
        raise RuntimeError, message: "Unable to start SSH server: #{inspect error}"
    end
  end

  defp start_cog(user, peer, state) do
    {:ok, pid} = Cog.Adapters.SSH.Shell.start(user, peer, state.bot_username, state.command_prefix)
    pid
  end

  def broadcast_message(room, sender, message, exclude \\ nil) do
    for [pid] <- get_room_pids(room), pid != exclude do
      Shell.send_message(pid, sender, message)
    end
  end

  def handle_info(:gc_room_pids, state) do
    Logger.debug("Running GC...")
    for [pid] <- :ets.match(:ssh_server, {:'_', :'$1'}) do
      unless Process.alive?(pid) do
        gc_room_pids(pid)
      end
    end

    Process.send_after(@server_name, :gc_room_pids, @gc_interval)
    {:noreply, state}
  end
  def handle_info({:publish, "/bot/adapters/ssh/send_message", message}, state) do
    case Carrier.CredentialManager.verify_signed_message(message) do
      {true, payload} ->
        json = Poison.decode!(payload)
        broadcast_message(json["room"]["name"], state.bot_username, json["text"])
      false ->
        Logger.error("Message signature not verified! #{inspect message}")
    end
    {:noreply, state}
  end
  def handle_info({:send_message, "/bot/adapters/ssh/send_message", payload}, state) do
    json = Poison.decode!(payload)
    broadcast_message(json["room"]["name"], state.bot_username, json["text"])
    {:noreply, state}
  end
  def handle_info({{:send_message, ref, sender}, room, message}, state) do
    broadcast_message(room, state.bot_username, message)
    send(sender, {ref, :ok})
    {:noreply, state}
  end
  def handle_info(message, state) do
    Logger.debug("#{__MODULE__}: Ignoring message #{inspect message}")
    {:noreply, state}
  end

  def enter_room(room, pid \\ self) do
    GenServer.call(@server_name, {:enter_room, room, pid}, :infinity)
  end

  def leave_room(room, pid \\ self) do
    GenServer.call(@server_name, {:leave_room, room, pid}, :infinity)
  end

  def leave_all_rooms(pid \\ self) do
    GenServer.call(@server_name, {:leave_all_rooms, pid}, :infinity)
  end

  def handle_call({:enter_room, room, pid}, _from, state) do
    :ets.insert(@server_name, {room, pid})
    {:reply, :ok, state}
  end
  def handle_call({:leave_room, room, pid}, _from, state) do
    :ets.match_delete(@server_name, {room, pid})
    {:reply, :ok, state}
  end
  def handle_call({:leave_all_rooms, pid}, _from, state) do
    :ets.match_delete(@server_name, {:'_', pid})
    {:reply, :ok, state}
  end

  def gc_room_pids(pid), do: :ets.match_delete(@server_name, {:'_', pid})

  def publish_message(sender, room, text) do
    GenServer.cast(@server_name, {:publish_message, sender, room, text})
  end

  def handle_cast({:publish_message, username, room, text}, state) do
    sender = %{handle: username}
    room = %{name: room}
    payload = %{sender: sender,
                room: room,
                text: text,
                adapter: @adapter_name,
                reply: "/bot/adapters/ssh/send_message"}
    Carrier.Messaging.Connection.publish(state.mq_conn, payload, routed_by: "/bot/commands")
    {:noreply, state}
  end

  def get_room_pids(room) do
    List.flatten(:ets.match(@server_name, {room, :'$1'}))
  end

  defp ensure_charlist_values(opts) do
    Enum.map(opts, fn({k,v}) -> {k, ensure_charlist(v)} end)
  end

  defp ensure_charlist(value) when is_binary(value), do: to_char_list(value)
  defp ensure_charlist(value), do: value

  defp fetch_required(config, key) do
    case Keyword.get(config, key) do
      nil ->
        raise ArgumentError, "missing #{inspect key} configuration in " <>
          "config #{inspect :cog}, #{inspect Cog.Adapters.SSH}"
      value ->
        value
    end
  end
end

defmodule Cog.Adapters.IRC.Connection do
  use GenServer
  alias Cog.Adapters.IRC

  defstruct [:client, :config]

  def send_message(room, message) do
    GenServer.call(__MODULE__, {:send_message, room, message})
  end

  def lookup_room("#" <> name) do
    lookup_room(name: name)
  end

  def lookup_room(name) when is_binary(name) do
    lookup_direct_room(name: name)
  end

  def lookup_room([{_key, _value}] = options) do
    GenServer.call(__MODULE__, {:lookup_room, options})
  end

  def lookup_direct_room([{_key, _value}] = options) do
    GenServer.call(__MODULE__, {:lookup_direct_room, options})
  end

  def start_link([client: client, config: config]) do
    GenServer.start_link(__MODULE__, [client: client, config: config], name: __MODULE__)
  end

  def init([client: client, config: config]) do
    ExIrc.Client.add_handler(client, self)

    connect = case config[:irc][:use_ssl] do
      true ->
        &ExIrc.Client.connect_ssl!/3
      false ->
        &ExIrc.Client.connect!/3
    end

    connect.(client, config[:irc][:host], config[:irc][:port])

    {:ok, %__MODULE__{client: client, config: config}}
  end

  def handle_call({:send_message, room, message}, _from, %{client: client} = state) do
    ExIrc.Client.msg(client, :privmsg, room["name"], message)
    {:reply, :ok, state}
  end

  def handle_call({:lookup_room, [{_key, name}]}, _from, %{client: client} = state) do
    channels = ExIrc.Client.channels(client)

    reply = if name in channels do
      {:ok, %{id: name, handle: name}}
    else
      {:error, :not_found}
    end

    {:reply, reply, state}
  end

  def handle_call({:lookup_room, _options}, _from, state) do
    {:reply, {:error, :invalid_options}, state}
  end

  def handle_call({:lookup_direct_room, [{_key, name}]}, _from, %{client: client} = state) do
    channels = ExIrc.Client.channels(client)
    names = Enum.flat_map(channels, &ExIrc.Client.channel_users(client, &1))

    reply = if name in names do
      {:ok, %{id: name, name: name}}
    else
      {:error, :not_found}
    end

    {:reply, reply, state}
  end

  def handle_call({:lookup_direct_room, _options}, _from, state) do
    {:reply, {:error, :invalid_options}, state}
  end

  def handle_info({:connected, _, _}, %{client: client, config: config} = state) do
    password = config[:irc][:password]
    nick     = config[:irc][:nick]
    user     = config[:irc][:user] || nick
    name     = config[:irc][:name] || nick

    ExIrc.Client.logon(client, password, nick, user, name)

    {:noreply, state}
  end

  def handle_info(:logged_in, %{client: client, config: config} = state) do
    channel = config[:irc][:channel]
    ExIrc.Client.join(client, channel)
    {:noreply, state}
  end

  def handle_info({:received, message, nick, channel}, %{config: config} = state) do
    with {true, message} <- command?(message, config[:irc][:nick]) do
      sender = %{id: nick, handle: nick}
      room = %{id: channel, name: channel}
      IRC.receive_message(sender, room, message)
    end

    {:noreply, state}
  end

  def handle_info(_message, state) do
    {:noreply, state}
  end

  def terminate(_reason, %{client: client}) do
    ExIrc.Client.stop!(client)
    :ok
  end

  defp command?(message, nick) do
    mention?(message, nick) || spoken?(message)
  end

  defp mention?(message, nick) do
    regex = ~r/^#{nick}:\s*/

    case Regex.split(regex, message, parts: 2) do
      ["", message] ->
        {true, message}
      _ ->
        false
    end
  end

  defp spoken?(message) do
    regex = ~r/^#{command_prefix}\s*/

    case {enable_spoken_commands?, Regex.split(regex, message, parts: 2)} do
      {true, ["", message]} ->
        {true, message}
      _ ->
        false
    end
  end

  defp enable_spoken_commands?,
    do: Application.get_env(:cog, :enable_spoken_commands, true)

  defp command_prefix,
    do: Application.get_env(:cog, :command_prefix, "!")
end

defmodule Cog.Adapters.SSH.Shell do
  require Logger

  import Cog.Adapters.SSH, only: [lookup_room: 1, lookup_user: 1]
  alias Cog.Adapters.SSH.Server, as: Server

  use GenServer

  defstruct current_user: nil, current_room: nil, command_pattern: nil,
    bot_username: nil, command_prefix: nil

  @initial_room "#default"
  @commands [
    help: "Display this help message.",
    user: "Change user context. Ex: 'user admin' to become the 'admin' user.",
    room: "Change room context. Ex: 'room #secret' to enter the '#secret' room.",
    exit: "Close the SSH session"
  ]

  def start(user, peer, bot_username, command_prefix) do
    GenServer.start(__MODULE__, [user, peer, bot_username, command_prefix])
  end

  def init([user, _peer, bot_username, command_prefix]) do
    {:ok, current_user} = lookup_user(name: user)

    command_pattern = ~r/\A#{command_prefix}\w+|@?#{bot_username}:\s?\w+/f
    state = %{current_user: current_user, current_room: @initial_room,
              bot_username: bot_username, command_prefix: command_prefix,
              command_pattern: command_pattern}

    # Start the command cog. This is safe to run in init because it
    # asks for the Shell's state via a call that won't return until
    # initialization is complete.
    Server.enter_room(state.current_room)
    spawn_link(__MODULE__, :command_cog, [self])

    {:ok, state}
  end

  def command_cog(parent) do
    {:ok, state} = get_state(parent)

    case read_line(state.current_user, state.current_room) do
      {:error, _type} ->
        exit(:abort)
      :exit ->
        :exit
      line ->
        String.strip(to_string(line))
        |> broadcast_line(state.current_room, state.current_user.username, parent)
        |> handle_line(state, parent)

        command_cog(parent)
    end
  end

  def read_line(user, room) do
    IO.gets(format_message(:prompt, user, room))
  end

  def broadcast_line(""=line, _, _, _), do: line
  def broadcast_line(line, room, username, parent) do
    Server.broadcast_message(room, username, line, parent)
    line
  end

  def handle_line(line, state, parent) do
    case parse_line(line) do
      :blank ->
        :nothing
      {:local_command, [function: command, args: args]} ->
        case GenServer.call(parent, {command, args}) do
          {_, reply} ->
            case reply do
              nil -> :nothing
              message ->
                Server.broadcast_message(state.current_room, state.bot_username, message)
            end
        end
      {:message, line} ->
        if Regex.match?(state.command_pattern, line) do
          Server.publish_message(state.current_user.username, state.current_room, line)
        end
    end
  end

  def parse_line(""), do: :blank
  def parse_line(line) do
    [prefix|args] = String.split(line)
    command = String.to_atom(prefix)

    case Keyword.has_key?(@commands, command) do
      true ->  {:local_command, [function: String.to_atom("command_#{command}"), args: args]}
      false -> {:message, line}
    end
  end

  def get_state(parent), do: GenServer.call(parent, :get_state, :infinity)

  def handle_call(:get_state, _from, state) do
    {:reply, {:ok, state}, state}
  end
  def handle_call({:command_help, []}, _from, state) do
    reply = to_string(Enum.map(@commands, &format_command/1))
    {:reply, {:ok, reply}, state}
  end
  def handle_call({:command_user, [user]}, _from, state) do
    case lookup_user(name: user) do
      {:ok, user} ->
        {:reply, {:ok, "User change: #{state.current_user.username} -> #{user.username}"}, %{state | current_user: user}}
      _ ->
        {:reply, {:error, "Unknown user: #{user}"}, state}
    end
  end
  def handle_call({:command_room, [room]}, _from, state) do
    Server.leave_room(state.current_room)
    Server.enter_room(room)

    {:reply, {:ok, "Room changed to #{room}"}, %{state | current_room: room}}
  end
  def handle_call({:command_exit, []}, _from, state) do
    {:stop, :normal, state}
  end

  def send_message(pid, sender, message) do
    GenServer.cast(pid, {:send_message, sender, message})
  end

  def handle_cast({:send_message, sender, message}, state) do
    for line <- String.split(message, "\n") do
      IO.puts(format_message(:reply, sender, state.current_room, line))
    end

    {:noreply, state}
  end
  def handle_cast({:run_command, command, args}, state) do
    function = "command_#{to_string(command)}" |> String.to_atom

    try do
      case apply(__MODULE__, function, [args, state]) do
        {:ok, reply, state} ->
          IO.puts(reply)
          {:ok, state}
        {:ok, state} ->
          {:noreply, state}
        :exit ->
          {:stop, :shell_exit, state}
      end
    rescue err in RuntimeError ->
      IO.puts("Error executing #{to_string(command)}: #{inspect(err)}")
      {:noreply, state}
    end
  end

  def format_command({command, text}) do
    :io_lib.format("~-15s ~s~n", [to_string(command), to_string(text)])
  end

  def format_message(:reply, sender, room, message) do
    IO.ANSI.format([
      [:yellow], room, [:default_color], ":",
      [:yellow], sender, [:default_color], ": ", message
    ], true)
  end
  def format_message(:prompt, user, room) do
    IO.ANSI.format([
      [:blue, :bright], room, [:default_color], ":",
      [:blue, :bright], user.username, [:default_color], " > "
    ], true)
  end

end

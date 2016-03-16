defmodule Cog.Adapters.HipChat.Connection do
  use GenServer
  alias Cog.Adapters.HipChat
  require Logger

  defstruct [:xmpp_conn, :command_pattern]

  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  def init(config) do
    {:ok, xmpp_conn} = config[:xmpp]
    |> Map.put(:config, xmpp_server_options)
    |> Hedwig.start_client

    command_pattern = compile_command_pattern(config[:api][:mention_name])

    {:ok, %{xmpp_conn: xmpp_conn, command_pattern: command_pattern}}
  end

  def xmpp_server_options do
    %{ignore_from_self: true, require_tls?: true}
  end

  def event_manager do
    GenServer.call(__MODULE__, :event_manager)
  end

  def receive_message(msg, opts) do
    GenServer.cast(__MODULE__, {:receive_message, msg, opts})
  end

  def handle_call(:event_manager, _from, state) do
    event_manager = Hedwig.Client.get(state.xmpp_conn, :event_manager)
    {:reply, event_manager, state}
  end

  def handle_cast({:receive_message, message, _options}, state) do
    case extract_command(message, state.command_pattern) do
      :not_found ->
        {:noreply, state}
      {type, command} ->
        {:ok, %{room: room, user: sender}} = message_source(message)
        handle_command(type, room, sender, command, state)
    end
  end

  defp message_source(message) do
    [_org_id, source] = String.split(message.from.user, "_", parts: 2)

    case message.type do
      "chat" ->
        with {:ok, user} <- HipChat.API.lookup_user(id: source) do
          {:ok, %{room: :direct, user: user}}
        end
      "groupchat" ->
        HipChat.API.lookup_room_user(source, message.from.resource)
    end
  end

  defp extract_command(message, command_pattern) do
    command = Regex.replace(command_pattern, message.body, "")

    cond do
      command == message.body ->
        :not_found
      message.type == "groupchat" ->
        case String.starts_with?(message.body, command_prefix) do
          true ->
            {:room, command}
          false ->
            {:mention, command}
        end
      message.type == "chat" ->
        {:direct, command}
    end
  end

  defp handle_command(:direct, _room, user_id, command, state) do
    forward_command(:direct, user_id, command, state)
  end
  defp handle_command(:mention, room, user_id, command, state) do
    forward_command(room, user_id, command, state)
  end
  defp handle_command(:room, room, user_id, command, state) do
    case Application.get_env(:cog, :enable_spoken_commands, true) do
      false ->
        {:noreply, state}
      true ->
        forward_command(room, user_id, command, state)
    end
  end

  defp forward_command(:direct, sender, text, state) do
    forward_command(%{direct: sender[:id]}, sender, text, state)
  end
  defp forward_command(room, sender, text, state) do
    HipChat.receive_message(sender, room, text)
    {:noreply, state}
  end

  defp compile_command_pattern(mention_name) do
    ~r/\A(@?#{mention_name}:?\s*)|(#{command_prefix})/i
  end

  defp command_prefix() do
    Application.get_env(:cog, :command_prefix, "!")
  end
end

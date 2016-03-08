defmodule Cog.Adapters.HipChat.Connection do
  use GenServer
  alias Cog.Adapters.HipChat
  require Logger

  defstruct xmpp_conn: nil

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    HipChat.API.start

    config = HipChat.Config.fetch_config!

    {:ok, xmpp_conn} = config[:xmpp]
    |> Map.put(:config, xmpp_server_options)
    |> Hedwig.start_client

    {:ok, %{xmpp_conn: xmpp_conn}}
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
  def handle_cast({:receive_message, msg, _opts}, state) do
    handle_inbound_message(msg, state)
  end

  def handle_call(:event_manager, _from, state) do
    event_manager = Hedwig.Client.get(state.xmpp_conn, :event_manager)
    {:reply, event_manager, state}
  end

  defp handle_inbound_message(message, state) do
    case extract_command(message) do
      :not_found ->
        {:noreply, state}
      {type, command} ->
        %{room: room, user: sender} = message_source(message)
        handle_command(type, room, sender, command, state)
    end
  end

  defp message_source(message) do
    case message.type do
      "chat" ->
        [_org_id, user_id] = String.split(message.from.user, "_", parts: 2)
        %{room: :direct, user: HipChat.API.lookup_user([id: user_id])}
      "groupchat" ->
        [_org_id, room_name] = String.split(message.from.user, "_", parts: 2)
        HipChat.API.lookup_room_user(room_name, message.from.resource)
    end
  end

  defp extract_command(message) do
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

  defp command_pattern() do
    ~r/\A(@?#{mention_name}:?\s*)|(#{command_prefix})/i
  end
  defp command_prefix() do
    Application.get_env(:cog, :command_prefix, "!")
  end

  defp mention_name() do
    config = HipChat.Config.fetch_config!(:api)
    config[:api][:mention_name]
  end
end

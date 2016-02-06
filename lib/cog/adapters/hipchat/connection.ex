defmodule Cog.Adapters.HipChat.Connection do
  require Logger

  alias Cog.Adapters.HipChat

  use GenServer

  @adapter_name "hipchat"
  @module_name Cog.Adapters.HipChat

  defstruct xmpp_conn: nil, mq_conn: nil

  def start_link() do
    GenServer.start_link(__MODULE__, HipChat.Config.fetch_config, name: __MODULE__)
  end

  def init(config) do
    HipChat.API.start

    {:ok, xmpp_conn} =
      Map.put(config[:xmpp], :config, xmpp_server_options)
      |> Hedwig.start_client
    {:ok, mq_conn} = Carrier.Messaging.Connection.connect()
    Carrier.Messaging.Connection.subscribe(mq_conn, "/bot/adapters/hipchat/+")

    {:ok, %{xmpp_conn: xmpp_conn, mq_conn: mq_conn}}
  end

  def xmpp_server_options do
    %{ignore_from_self: true, require_tls?: true}
  end

  def event_manager do
    GenServer.call(__MODULE__, :event_manager)
  end

  def handle_info({:publish, "/bot/adapters/hipchat/send_message", message}, state) do
    case Carrier.CredentialManager.verify_signed_message(message) do
      {true, payload} ->
        message = render_template(payload)
        case message_target(payload["room"]) do
          {:direct, dest} ->
            HipChat.API.send_direct_message(dest, message)
          {:room, room_id} ->
            HipChat.API.send_message(room_id, message)
        end
        {:noreply, state}
      false ->
        Logger.error("Message signature not verified! #{inspect message}")
        {:noreply, state}
    end
  end
  def handle_info(_req, state) do
    {:noreply, state}
  end

  defp message_target(target) when is_map(target) do
    case target["direct"] do
      nil ->
        {:room, target["id"]}
      target ->
        {:direct, target}
    end
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
    payload = %{sender: sender,
                room: room,
                text: text,
                adapter: @adapter_name,
                module: @module_name,
                reply: "/bot/adapters/hipchat/send_message"}
    Carrier.Messaging.Connection.publish(state.mq_conn, payload, routed_by: "/bot/commands")
    {:noreply, state}
  end

  # TODO: Replace Slack rendering with HipChat specific output formatting once our formatting and templating take shape.
  defp render_template(json) do
    strip_code_markdown = ~r/(\A```)|(```\z)/
    "/code " <> Regex.replace(strip_code_markdown, json["response"], "")
  end

  defp command_pattern() do
    ~r/\A(@?#{mention_name}:?\s*)|(#{command_prefix})/i
  end
  defp command_prefix() do
    Application.get_env(:cog, :command_prefix, "!")
  end

  defp mention_name() do
    HipChat.Config.fetch_config(:api)
    |> Access.get(:mention_name)
  end
end

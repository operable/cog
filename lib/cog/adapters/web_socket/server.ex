defmodule Cog.Adapters.WebSocket.Server do
  alias Carrier.Messaging.Connection

  defstruct mq_conn: nil, bot_username: nil

  @adapter_name "websocket"
  @behaviour :websocket_client_handler

  def start_link(websocket_uri, bot_username) do
    :websocket_client.start_link(websocket_uri, __MODULE__, [bot_username])
  end

  def init([bot_username], _ws_conn) do
    {:ok, mq_conn} = Connection.connect
    Connection.subscribe(mq_conn, "/bot/adapters/websocket/+")

    Process.register(self, __MODULE__)

    state = %__MODULE__{mq_conn: mq_conn, bot_username: bot_username}
    {:ok, state}
  end

  def websocket_handle({:text, text}, _ws_conn, state) do
    %{"sender" => sender, "room" => room, "text" => text} = Poison.decode!(text)

    cond do
      String.starts_with?(text, state.bot_username) ->
        handle_command(sender, room, text, state)
      true ->
        {:ok, state}
    end
  end

  def websocket_info({:publish, "/bot/adapters/websocket/send_message", payload}, _ws_conn, state) do
    json = Poison.decode!(payload)
    text = state.bot_username <> ": " <> render_template(json)

    {:reply, {:text, text}, state}
  end
  def websocket_info({:text, text}, ws_conn, state) do
    :websocket_client.send({:text, text}, ws_conn)

    {:ok, state}
  end
  def websocket_info(_, _, state) do
    {:ok, state}
  end

  def websocket_terminate(_reason, _conn, _state) do
    :ok
  end

  def message(message) do
    :websocket_client.cast(__MODULE__, {:text, message})
  end

  defp handle_command(sender, room, text, state) do
    text = Regex.replace(~r/^#{state.bot_username}:\s*/, text, "")
    payload = %{
      "sender" => sender,
      "room" => room,
      "text" =>  text,
      "adapter" => @adapter_name,
      "reply" => "/bot/adapters/websocket/send_message"
    }
    Connection.publish(state.mq_conn, payload, routed_by: "/bot/commands")
    {:ok, state}
  end

  defp render_template(%{"template" => template, "assigns" => assigns}) do
    Cog.Templates.render(template, "websocket", assigns)
  end
end

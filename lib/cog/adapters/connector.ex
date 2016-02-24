defmodule Cog.Adapters.Connector do
  use GenServer
  require Logger

  def forward_command(adapter, sender, room, text) do
    GenServer.call(String.to_atom(adapter.service_name()), {:forward_command, sender, room, text})
  end

  def start_link(adapter) do
    GenServer.start_link(__MODULE__, adapter, name: String.to_atom(adapter.service_name()))
  end

  def init(adapter) do
    bus_name = adapter.bus_name()
    topic = "/bot/adapters/#{bus_name}/+"

    {:ok, conn} = Carrier.Messaging.Connection.connect()
    Carrier.Messaging.Connection.subscribe(conn, topic)

    {:ok, %{adapter: adapter, conn: conn}}
  end

  def handle_call({:forward_command, sender, room, text}, _from, state) do
    adapter = state.adapter

    payload = %{sender: sender,
                room: room,
                text: text,
                adapter: adapter.bus_name,
                module: to_string(adapter),
                reply: "/bot/adapters/#{state.adapter.bus_name()}/send_message"}

    Carrier.Messaging.Connection.publish(state.conn, payload, routed_by: "/bot/commands")

    {:reply, :ok, state}
  end

  def handle_info({:publish, topic, message}, state) do
    adapter = state.adapter
    bus_name = adapter.bus_name()
    send_message_topic = "/bot/adapters/#{bus_name}/send_message"

    case topic do
      ^send_message_topic ->
        case Carrier.CredentialManager.verify_signed_message(message) do
          {true, payload} ->
            adapter.send_message(payload["room"]["id"], payload["response"])
          false ->
            Logger.error("Message signature not verified! #{inspect message}")
        end

        {:noreply, state}
      _ ->
        {:noreply, state}
    end
  end

  def handle_info(_, state) do
    {:noreply, state}
  end
end

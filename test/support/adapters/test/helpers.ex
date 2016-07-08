defmodule Cog.Adapters.Test.Helpers do
  alias Cog.Models.User
  alias Carrier.Messaging.Connection

  @timeout 5000 # 5 seconds

  def send_message(%User{username: username}, "@bot: " <> message) do
    {:ok, mq_conn} = Connection.connect
    reply_topic = "/bot/adapters/test/send_message"
    id = UUID.uuid4(:hex)
    initial_context = %{}
    payload = %{id: id,
                sender: %{id: username, handle: username},
                room: %{id: "general", name: "general"},
                text: message,
                adapter: "test",
                initial_context: initial_context,
                module: Cog.Adapters.Test,
                reply: reply_topic}
    Connection.subscribe(mq_conn, reply_topic)
    Connection.publish(mq_conn, payload, routed_by: "/bot/commands")

    loop_until_received(mq_conn, reply_topic, id)
  end

  defp loop_until_received(mq_conn, reply_topic, id) do
    receive do
      {:publish, ^reply_topic, compressed} ->
        {:ok, msg} = Connection.decompress(compressed)
        message = Poison.decode!(msg)
        case Map.get(message, "id") do
          ^id ->
            :emqttc.disconnect(mq_conn)
            message
          _ ->
            loop_until_received(mq_conn, reply_topic, id)
        end
    after @timeout ->
        :emqttc.disconnect(mq_conn)
        raise(RuntimeError, "Connection timed out waiting for a response")
    end
  end

end

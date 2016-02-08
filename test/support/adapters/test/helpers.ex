defmodule Cog.Adapters.Test.Helpers do
  alias Cog.Models.User
  alias Carrier.Messaging.Connection

  @timeout 5000 # 5 seconds

  def send_message(%User{username: username}, "@bot: " <> message) do
    {:ok, mq_conn} = Connection.connect
    reply_topic = "/bot/adapters/test/#{:erlang.unique_integer([:positive, :monotonic])}"
    payload = %{sender: %{id: 1, handle: username},
                room: %{id: 1, name: "general"},
                text: message,
                adapter: "test",
                module: Cog.Adapters.Test,
                reply: reply_topic}
    Connection.subscribe(mq_conn, reply_topic)
    Connection.publish(mq_conn, payload, routed_by: "/bot/commands")

    receive do
      {:publish, ^reply_topic, msg} ->
        :emqttc.disconnect(mq_conn)
        Poison.decode!(msg)
    after @timeout ->
        raise(RuntimeError, "Connection timed out waiting for a response")
        :emqttc.disconnect(mq_conn)
        {:error, :timeout}
    end
  end

  #def assert_response(message) do
    #Assertions.polling_assert(message, &last_message/0, @interval, @timeout)
  #end

  #def assert_payload(payload) do
    #Assertions.polling_assert(payload, &last_response/0, @interval, @timeout)
  #end

  #def assert_response_in(message) do
    #Assertions.polling_assert_in(message, &last_message/0, @interval, @timeout)
  #end

  #def get_response do
    #Assertions.polling(&last_message/0, @interval, @timeout)
  #end

  #defp last_message() do
    #Cog.Adapters.Test.last_message(true)
  #end

  #defp last_response() do
    #Cog.Adapters.Test.last_response(true)
  #end

end

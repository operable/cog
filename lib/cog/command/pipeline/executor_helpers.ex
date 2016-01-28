defmodule Cog.Command.Pipeline.Executor.Helpers do
  require Logger

  def send_error(error, payload, mq_conn) when is_binary(error) do
    send_reply("Whoops! An error occurred. #{error}", payload, mq_conn)
  end
  def send_error(error, payload, mq_conn) do
    Logger.warn("The error message #{inspect error} should be in string format for displaying to the user")
    send_reply("Whoops! An error occurred. #{inspect error}", payload, mq_conn)
  end

  def send_timeout(command, payload, mq_conn) do
    send_reply("Hmmm. The #{command} command timed out.", payload, mq_conn)
  end

  def send_idk(payload, command, mq_conn) do
    send_reply("Sorry, I don't know the '#{command}' command :(", payload, mq_conn)
  end

  def send_wat(payload, mq_conn) do
    send_reply("Wat. I didn't understand what you said.", payload, mq_conn)
  end

  def send_not_available(type, payload, mq_conn) do
    send_reply("Sorry, I haven't learned how to execute #{type} yet :(", payload, mq_conn)
  end

  def send_denied(which, why \\ "", payload, mq_conn) do
    send_reply("Sorry, you aren't allowed to execute '#{which}' :(\n #{why}", payload, mq_conn)
  end

  def send_reply(message, payload, mq_conn) do
    message = if payload["room"]["name"] != "direct" do
      "@#{payload["sender"]["handle"]} " <> message
    else
      message
    end
    reply = %{room: payload["room"], response: message, adapter: payload["adapter"]}
    Carrier.Messaging.Connection.publish(mq_conn, reply, routed_by: payload["reply"])
  end
end

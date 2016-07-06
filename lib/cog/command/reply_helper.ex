defmodule Cog.Command.ReplyHelper do
  alias Carrier.Messaging.Connection
  alias Cog.Template

  @doc """
  Renders a template and sends it to the originating room
  """
  @spec send_template(map, String.t, map, Connection.connection) :: :ok | {:error, any}
  def send_template(request, template_name, context, conn) do
    send_template(request, template_name, request["room"], context, conn)
  end

  @doc """
  Renders a template and send it to a designated room
  """
  @spec send_template(map, String.t, String.t, map, Connection.connection) :: :ok | {:error, any}
  def send_template(request, template_name, room_name, context, conn) do
    case Template.render(request["adapter"], template_name, context) do
      {:ok, message} ->
        publish_response(message, room_name, request["adapter"], conn)
      error ->
        error
    end
  end

  defp publish_response(message, room, adapter, conn) do
    response = %{response: message,
                 room: room}
    {:ok, adapter_mod} = Cog.adapter_module(adapter)

    reply_topic = adapter_mod.reply_topic

    # Slack has a limit of 16kb (https://api.slack.com/rtm#limits),
    # while HipChat has 10,000 characters
    # (https://developer.atlassian.com/hipchat/guide/sending-messages). Eventually,
    # over-long messages will need adapter-specific customization
    # (breaking into multiple messages, using alternative formats
    # (e.g. Slack attachments), etc.). For now, though, we can at the
    # very least tell Carrier to emit a warning when we get a message
    # that looks like it is potentially too big.
    Connection.publish(conn, response, routed_by: reply_topic, threshold: 10000)
  end

end

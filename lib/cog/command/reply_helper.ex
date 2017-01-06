defmodule Cog.Command.ReplyHelper do
  alias Cog.Chat.Adapter
  alias Cog.Template.Evaluator

  @doc """
  Utility function for sending data formatted by a common template
  (i.e., not a bundle-specific one) to a destination.

  If the targeted provider is a chat provider, the data is processed
  with the template to generate directives, which are then rendered to
  text by the provider. If it is not a chat provider (e.g., the "http"
  provider), no template rendering is performed, and the raw data
  itself is sent instead.
  """

  def send(common_template, message_data, room, provider, connection) do
    directives = Evaluator.evaluate(common_template, message_data)
    payload = if Adapter.is_chat_provider?(provider) do
      directives
    else
      message_data
    end

    Adapter.send(connection, provider, room, payload)
  end

end

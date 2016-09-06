defmodule Cog.Command.ReplyHelper do
  alias Cog.Chat.Adapter
  alias Cog.Template.New.Evaluator

  @doc """
  Utility function for sending data formatted by a common template
  (i.e., not a bundle-specific one) to a destination.

  If the targeted provider is a chat provider, the data is processed
  with the template to generate directives, which are then rendered to
  text by the provider. If it is not a chat provider (e.g., the "http"
  provider), no template rendering is performed, and the raw data
  itself is sent instead.
  """
  def send(common_template, message_data, room, adapter, connection) do
    # TODO: it'd be nice to generate directives only if necessary :/
    # As it is, though, this will currently only happen if we're
    # sending a common template to the HTTP provider, so we can deal
    # with this later.
    directives = Evaluator.evaluate(common_template, message_data)
    payload = choose_payload(adapter, directives, message_data)

    publish(connection, adapter, room, payload)
  end

  def choose_payload(adapter, directives, message_data) do
    if Adapter.is_chat_provider?(adapter) do
      directives
    else
      message_data
    end
  end

  def publish(connection, adapter, room, payload),
    do: Adapter.send(connection, adapter, room, payload)

end

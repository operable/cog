# Currently only used to render Slack threads, but is intended to be used to
# store information about the original message used in rendering and sending
# the response.
defmodule Cog.Chat.MessageMetadata do
  use Conduit

  field :thread_id, :string, required: false
  field :originating_room_id, :string, required: false
end

defmodule Cog.Chat.MessageMetadata do
  use Conduit

  field :thread_id, :string, required: false
  field :originating_room_id, :string, required: false
end

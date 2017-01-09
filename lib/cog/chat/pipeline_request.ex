defmodule Cog.Chat.PipelineRequest do
  use Conduit

  alias Cog.Chat.User
  alias Cog.Chat.Room

  # Command coming in from Chat
  field :text, :string, required: true

  field :sender, [object: User], required: true

  field :room, [object: Room], required: true

  field :initial_context, :map, required: true

  # Short name of adapter, e.g. "slack"
  field :provider, :string, required: true

end

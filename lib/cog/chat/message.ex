defmodule Cog.Chat.Message do

  use Conduit

  field :id, :string, required: true
  field :room, [object: Cog.Chat.Room], required: true
  field :user, [object: Cog.Chat.User], required: true
  field :text, :string, required: true
  field :provider, :string, required: true
  field :edited, :bool, required: false
  field :initial_context, :map, required: false
  field :bot_name, :string, required: false
  field :metadata, [object: Cog.Chat.MessageMetadata], required: false

end

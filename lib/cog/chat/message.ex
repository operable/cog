defmodule Cog.Chat.Message do

  use Conduit

  field :id, :string, required: true
  field :timestamp, :integer, required: false
  field :room, [object: Cog.Chat.Room], required: true
  field :user, [object: Cog.Chat.User], required: true
  field :text, :string, required: true
  field :provider, :string, required: true
  field :edited, :bool, required: false
  field :initial_context, :map, required: false
  field :bot_name, :string, required: false

  def age(message) do
    now = System.system_time(:milliseconds)
    if message.timestamp == nil do
      0
    else
      now - message.timestamp
    end
  end

end

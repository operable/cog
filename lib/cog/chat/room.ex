defmodule  Cog.Chat.Room do

  use Conduit

  field :id, :string, required: true
  field :name, :string, required: true
  field :provider, :string, required: true
  field :is_dm, :bool, required: true

end

defmodule Cog.Chat.User do

  use Conduit

  field :id, :string, required: true
  field :provider, :string, required: true
  field :email, :string, required: false
  field :first_name, :string, required: false
  field :last_name, :string, required: false
  field :handle, :string, required: true
  field :mention_name, :string, required: false

end

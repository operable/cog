defmodule Cog.Chat.User do

  use Conduit

  field :id, :string, required: true
  field :provider, :string, required: true
  field :email, :string, required: false
  field :first_name, :string, required: true
  field :last_name, :string, required: true
  field :handle, :string, required: true

end

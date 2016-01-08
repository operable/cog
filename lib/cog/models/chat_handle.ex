defmodule Cog.Models.ChatHandle do
  use Ecto.Model

  @primary_key false

  schema "chat_handles" do
    field :handle, :string
    field :user_id, Ecto.UUID
    field :provider_id, :integer
    has_one :user, Cog.Models.User, foreign_key: :user_id, references: :user_id
    has_one :chat_provider, Cog.Models.ChatProvider, foreign_key: :id, references: :provider_id

    timestamps
  end

end

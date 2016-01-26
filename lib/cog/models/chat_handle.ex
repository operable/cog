defmodule Cog.Models.ChatHandle do
  use Cog.Model
  use Cog.Models
  use Cog.Models.EctoJson

  schema "chat_handles" do
    field :handle, :string
    field :user_id, Ecto.UUID
    field :provider_id, :integer
    has_one :user, Cog.Models.User, foreign_key: :id, references: :user_id
    has_one :chat_provider, Cog.Models.ChatProvider, foreign_key: :id, references: :provider_id

    timestamps
  end

  @required_fields ~w(handle user_id provider_id)
  @optional_fields ~w()

  summary_fields [:id, :handle, :user_id, :provider_id]
  detail_fields [:id, :handle, :user, :chat_provider]

  def changeset(model, params \\ :empty) do
    model
    |> cast(params, @required_fields, @optional_fields)
  end

end

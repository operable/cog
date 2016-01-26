defmodule Cog.Models.ChatHandle do
  use Cog.Model
  use Cog.Models
  use Cog.Models.EctoJson

  schema "chat_handles" do
    field :handle, :string
    belongs_to :user, Cog.Models.User
    belongs_to :chat_provider, Cog.Models.ChatProvider, foreign_key: :provider_id, type: :integer

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

defmodule Cog.Models.Token do
  use Cog.Model
  alias Cog.Models.User

  schema "tokens" do
    field :value, :string
    belongs_to :user, User
    timestamps
  end

  @required_fields ~w(value)
  @optional_fields ~w()

  summary_fields [:value]
  detail_fields [:value]

  @token_bytes 32

  @doc """
  Insert a new token.
  """
  def insert_new(%User{}=user, params) do
    user
    |> Ecto.Model.build(:tokens, params)
    |> changeset(params)
    |> Repo.insert
  end

  @doc """
  Creates a changeset based on the `model` and `params`.

  If no params are provided, an invalid changeset is returned
  with no validation performed.
  """
  def changeset(model, params) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> unique_constraint(:users_tokens_must_be_unique, name: "tokens_user_id_value_index")
  end

  @doc """
  Generate a new base64-encoded token.
  """
  def generate do
    @token_bytes
    |> :crypto.rand_bytes
    |> Base.encode64
  end

end

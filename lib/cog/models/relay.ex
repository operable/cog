defmodule Cog.Models.Relay do
  use Cog.Model
  alias Cog.Passwords

  alias Cog.Models.RelayGroupMembership

  schema "relays" do
    field :name, :string
    field :token, :string, virtual: true
    field :token_digest, :string
    field :enabled, :boolean, default: false
    field :description, :string

    has_many :group_memberships, RelayGroupMembership, foreign_key: :relay_id
    has_many :groups, through: [:group_memberships, :group]

    timestamps
  end

  @required_fields ~w(name)
  @optional_fields ~w(token enabled description)

  def changeset(model, params \\ :empty) do
    model
    |> Repo.preload(:groups)
    |> cast(params, @required_fields, @optional_fields)
    |> allow_user_defined_id_on_insert(params)
    |> validate_presence_on_insert(:token)
    |> encode_token
    |> unique_constraint(:name)
  end

  def allow_user_defined_id_on_insert(changeset, params) do
    case {get_field(changeset, :id), Map.get(params, "id")} do
      {_, nil} ->
        changeset
      {nil, _} ->
        changeset |> cast(params, [], [:id])
      _ ->
        changeset
        |> add_error(:id, "cannot modify ID")
    end
  end

  def validate_presence_on_insert(changeset, :token) do
    case {get_field(changeset, :id), get_field(changeset, :token)} do
      {nil, nil} ->
        changeset
        |> add_error(:token, "can't be blank")
      _ ->
        changeset
    end
  end

  def encode_token(changeset) do
    case fetch_change(changeset, :token) do
      {:ok, token} ->
        changeset
        |> put_change(:token_digest, Passwords.encode(token))
      :error ->
        changeset
    end
  end

end

defimpl Groupable, for: Cog.Models.Relay do

  def add_to(relay, relay_group),
    do: Cog.Models.JoinTable.associate(relay, relay_group)

  def remove_from(relay, relay_group),
    do: Cog.Models.JoinTable.dissociate(relay, relay_group)

end

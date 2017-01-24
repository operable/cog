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
  @optional_fields ~w(id token enabled description)

  def changeset(model, params \\ %{}) do
    model
    |> Repo.preload(:groups)
    |> cast(params, @required_fields, @optional_fields)
    |> allow_user_defined_id_on_insert
    |> validate_presence_on_insert(:token)
    |> encode_token
    |> relay_group_membership_constraint
    |> unique_constraint(:name)
  end

  def allow_user_defined_id_on_insert(changeset) do
    case {Map.get(changeset.data, :id), get_field(changeset, :id)} do
      {nil, nil} ->
        changeset
      {nil, user_defined_id} ->
        put_change(changeset, :id, String.downcase(user_defined_id))
      {id, id} ->
        changeset
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

  defp relay_group_membership_constraint(changeset) do
    foreign_key_constraint(changeset,
                           :id,
                           name: :relay_group_memberships_relay_id_fkey,
                           message: "cannot delete relay that is a member of a relay group")
  end
end

defimpl Groupable, for: Cog.Models.Relay do

  def add_to(relay, relay_group),
    do: Cog.Models.JoinTable.associate(relay, relay_group)

  def remove_from(relay, relay_group),
    do: Cog.Models.JoinTable.dissociate(relay, relay_group)

end

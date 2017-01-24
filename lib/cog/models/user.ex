defmodule Cog.Models.User do
  use Cog.Model
  use Cog.Models.EctoJson

  alias Cog.Passwords
  alias Cog.Models.Permission
  alias Cog.Models.UserGroupMembership
  alias Cog.Models.UserPermission
  alias Cog.Models.UserRole
  alias Cog.Models.ChatHandle

  schema "users" do
    field :username, :string
    field :first_name, :string
    field :last_name, :string
    field :email_address, :string
    field :password, :string, virtual: true
    field :password_digest, :string

    has_many :chat_handles, ChatHandle

    has_many :group_memberships, UserGroupMembership, foreign_key: :member_id
    has_many :direct_group_memberships, through: [:group_memberships, :group]

    has_many :permission_grants, UserPermission
    has_many :permissions, through: [:permission_grants, :permission]

    has_many :role_grants, UserRole
    has_many :roles, through: [:role_grants, :role]

    has_many :tokens, Cog.Models.Token

    has_many :triggers, Cog.Models.Trigger, foreign_key: :as_user, references: :username

    timestamps
  end

  @required_fields ~w(username email_address)
  @optional_fields ~w(first_name last_name password)

  summary_fields [:id, :first_name, :last_name, :email_address, :username]
  detail_fields [:id, :first_name, :last_name, :email_address, :username]

  @doc """
  Returns `true` if `user` has `permission` granted. This takes into
  account recursive group membership and role grants.
  """
  def has_permission(%__MODULE__{}=user, %Permission{}=permission) do
    alias Ecto.Adapters.SQL
    import Cog.UUID
    %{rows: [[result]]} = SQL.query!(Repo,
                                     "SELECT user_has_permission($1, $2)",
                                     [uuid_to_bin(user.id),
                                      uuid_to_bin(permission.id)])
    result
  end

  @doc """
  Returns list of fully-qualified permissions names granted to the
  user. This takes into account recursive group memberhip and role
  grants.
  """
  def all_permissions(%__MODULE__{}=user) do
    alias Ecto.Adapters.SQL
    import Cog.UUID
    results = SQL.query!(Repo,
                         "SELECT fetch_user_permissions($1)",
                         [uuid_to_bin(user.id)])
    Enum.map(results.rows, fn([{_uuid, name}]) -> name end)
  end

  @doc """
  Creates a changeset based on the `model` and `params`.

  If no params are provided, an invalid changeset is returned
  with no validation performed.
  """
  def changeset(model, params \\ :empty) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> validate_presence_on_insert(:password)
    |> encode_password
    |> user_group_membership_constraint
    |> unique_constraint(:username)
  end

  # Prevent deletion of the user if they're attached to any triggers
  def delete_changeset(model) do
    model
    |> change
    |> no_assoc_constraint(:triggers)
  end

  def validate_presence_on_insert(changeset, :password) do
    case {get_field(changeset, :id), get_field(changeset, :password)} do
      {nil, nil} ->
        changeset
        |> add_error(:password, "can't be blank")
      _ ->
        changeset
    end
  end

  def encode_password(changeset) do
    case fetch_change(changeset, :password) do
      {:ok, password} ->
        changeset
        |> put_change(:password_digest, Passwords.encode(password))
      :error ->
        changeset
    end
  end

  defp user_group_membership_constraint(changeset) do
    foreign_key_constraint(changeset,
                           :id,
                           name: :user_group_membership_member_id_fkey,
                           message: "cannot delete user that is a member of a group")
  end
end

defimpl Permittable, for: Cog.Models.User do
  alias Cog.Models.JoinTable

  def grant_to(user, permission_or_role),
    do: JoinTable.associate(user, permission_or_role)

  def revoke_from(user, permission_or_role),
    do: JoinTable.dissociate(user, permission_or_role)

end

defimpl Groupable, for: Cog.Models.User do

  def add_to(user, group),
    do: Cog.Models.JoinTable.associate(user, group)

  def remove_from(user, group) do
    try do
      Cog.Models.JoinTable.dissociate(user, group)
    rescue
      error in [Postgrex.Error] ->
        case error do
          # Handle exception from protected_admin_group_memberships trigger
          %Postgrex.Error{postgres: %{code: :raise_exception,
                                      message: "cannot remove admin user from cog-admin group"}} ->
            {:error, :cannot_remove_admin_user}
        end
    end
  end

end

defimpl Poison.Encoder, for: Cog.Models.User do
  def encode(struct, options) do
    map = struct
    |> Map.from_struct
    |> Map.take([:id, :username, :first_name, :last_name, :email_address])

    Poison.Encoder.Map.encode(map, options)
  end
end

defmodule Cog.Models.Group do
  use Cog.Model
  use Cog.Models.EctoJson

  alias Cog.Models.GroupRole
  alias Cog.Models.UserGroupMembership
  alias Cog.Models.User
  alias Cog.Models.Role

  alias Ecto.Changeset

  schema "groups" do
    field :name, :string

    many_to_many :users, User, join_through: UserGroupMembership, join_keys: [group_id: :id, member_id: :id]
    many_to_many :roles, Role, join_through: GroupRole
  end

  @required_fields ~w(name)
  @optional_fields ~w()

  summary_fields [:id, :name]
  detail_fields [:id, :name]

  @doc """
  If no params are provided, an invalid changeset is returned
  with no validation performed.
  """
  def changeset(model), do: changeset(model, :empty)

  @doc """
  Creates a changeset based on the `model` to validate a delete
  action.
  """
  def changeset(model, :delete) do
    %{Changeset.change(model) | action: :delete}
    |> protect_admin_group
  end

  @doc """
  Creates a changeset based on the `model` and `params`.
  """
  def changeset(model, params) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> protect_admin_group
    |> unique_constraint(:name, name: :groups_name_index)
  end

  defp protect_admin_group(%Changeset{data: data}=changeset) do
    if data.name == Cog.Util.Misc.admin_group do
      changeset
      |> add_error(:name, "admin group may not be modified")
    else
      changeset
    end
  end

end

defimpl Permittable, for: Cog.Models.Group do

  def grant_to(group, permission_or_role),
    do: Cog.Models.JoinTable.associate(group, permission_or_role)

  def revoke_from(%Cog.Models.Group{name: unquote(Cog.Util.Misc.admin_group)=group_name},
                  %Cog.Models.Role{name: unquote(Cog.Util.Misc.admin_role)=role_name}),
    do: {:error, {:permanent_role_grant, role_name, group_name}}
  def revoke_from(group, permission_or_role),
    do: Cog.Models.JoinTable.dissociate(group, permission_or_role)

end

defimpl Poison.Encoder, for: Cog.Models.Group do
  def encode(struct, options) do
    map = struct
    |> Map.from_struct
    |> Map.take([:id, :name, :roles, :users])

    Poison.Encoder.Map.encode(map, options)
  end
end

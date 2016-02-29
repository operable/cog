defmodule Cog.Models.Role do
  use Cog.Model
  use Cog.Models.EctoJson

  schema "roles" do
    field :name, :string

    has_many :user_grants, Cog.Models.UserRole
    has_many :group_grants, Cog.Models.GroupRole

    has_many :permission_grants, Cog.Models.RolePermission
    has_many :permissions, through: [:permission_grants, :permission]
  end

  summary_fields [:id, :name]
  detail_fields [:id, :name]

  @required_fields ~w(name)
  @optional_fields ~w()

  def changeset(model, params \\ :empty) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> unique_constraint(:name)
  end

end

defimpl Permittable, for: Cog.Models.Role do

  def grant_to(role, permission),
    do: Cog.Models.JoinTable.associate(role, permission)

  def revoke_from(role, permission),
    do: Cog.Models.JoinTable.dissociate(role, permission)

end

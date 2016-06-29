defmodule Cog.Models.RolePermission do
  use Cog.Model
  alias Cog.Models.{Role, Permission}

  @primary_key false

  schema "role_permissions" do
    belongs_to :role, Role, primary_key: true
    belongs_to :permission, Permission, primary_key: true
  end

  @required_fields ~w(role_id permission_id)

  def changeset(model, params) do
    model
    |> cast(params, @required_fields)
    |> unique_constraint(:permission_grant , name: "role_permissions_role_id_permission_id_index")
  end
end

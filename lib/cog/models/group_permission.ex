defmodule Cog.Models.GroupPermission do
  use Cog.Model
  @primary_key false
  schema "group_permissions" do
    belongs_to :group, Cog.Models.Group, references: :id
    belongs_to :permission, Cog.Models.Permission, references: :id
  end

  @required_fields ~w(group_id permission_id)

  def changeset(model, params) do
    model
    |> cast(params, @required_fields)
    |> unique_constraint(:permission_grant , name: "group_permissions_group_id_permission_id_index")
  end
end

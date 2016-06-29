defmodule Cog.Models.GroupPermission do
  use Cog.Model
  alias Cog.Models.{Group, Permission}

  @primary_key false

  schema "group_permissions" do
    belongs_to :group, Group, primary_key: true
    belongs_to :permission, Permission, primary_key: true
  end

  @required_fields ~w(group_id permission_id)

  def changeset(model, params) do
    model
    |> cast(params, @required_fields)
    |> unique_constraint(:permission_grant , name: "group_permissions_group_id_permission_id_index")
  end
end

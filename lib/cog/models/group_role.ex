defmodule Cog.Models.GroupRole do
  use Cog.Model
  alias Cog.Models.{Group, Role}

  @primary_key false

  schema "group_roles" do
    belongs_to :group, Group, primary_key: true
    belongs_to :role, Role, primary_key: true
  end

  @required_fields ~w(group_id role_id)

  def changeset(model, params) do
    model
    |> cast(params, @required_fields)
    |> unique_constraint(:role_grant , name: "group_roles_group_id_role_id_index")
  end
end

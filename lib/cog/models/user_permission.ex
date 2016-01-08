defmodule Cog.Models.UserPermission do
  use Cog.Model
  @primary_key false
  schema "user_permissions" do
    belongs_to :user, Cog.Models.User, references: :id
    belongs_to :permission, Cog.Models.Permission, references: :id
  end

  @required_fields ~w(user_id permission_id)

  def changeset(model, params) do
    model
    |> cast(params, @required_fields)
    |> unique_constraint(:permission_grant , name: "user_permissions_user_id_permission_id_index")
  end
end

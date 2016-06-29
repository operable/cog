defmodule Cog.Models.UserPermission do
  use Cog.Model
  alias Cog.Models.{User, Permission}

  @primary_key false

  schema "user_permissions" do
    belongs_to :user, User, primary_key: true
    belongs_to :permission, Permission, primary_key: true
  end

  @required_fields ~w(user_id permission_id)

  def changeset(model, params) do
    model
    |> cast(params, @required_fields)
    |> unique_constraint(:permission_grant , name: "user_permissions_user_id_permission_id_index")
  end
end

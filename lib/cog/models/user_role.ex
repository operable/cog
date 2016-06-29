defmodule Cog.Models.UserRole do
  use Cog.Model
  alias Cog.Models.{User, Role}

  @primary_key false

  schema "user_roles" do
    belongs_to :user, User, primary_key: true
    belongs_to :role, Role, primary_key: true
  end

  @required_fields ~w(user_id role_id)

  def changeset(model, params) do
    model
    |> cast(params, @required_fields)
    |> unique_constraint(:role_grant , name: "user_roles_user_id_role_id_index")
  end

end

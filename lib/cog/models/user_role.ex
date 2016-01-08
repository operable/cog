defmodule Cog.Models.UserRole do
  use Cog.Model

  @primary_key false
  schema "user_roles" do
    belongs_to :user, Cog.Models.User, references: :id
    belongs_to :role, Cog.Models.Role, references: :id
  end

  @required_fields ~w(user_id role_id)

  def changeset(model, params) do
    model
    |> cast(params, @required_fields)
    |> unique_constraint(:role_grant , name: "user_roles_user_id_role_id_index")
  end

end

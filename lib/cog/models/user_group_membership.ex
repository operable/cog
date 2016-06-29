defmodule Cog.Models.UserGroupMembership do
  use Cog.Model
  alias Cog.Models.{User, Group}

  @primary_key false

  schema "user_group_membership" do
    belongs_to :member, User, primary_key: true
    belongs_to :group, Group, primary_key: true
  end

  @required_fields ~w(member_id group_id)

  def changeset(model, params) do
    model
    |> cast(params, @required_fields)
    |> unique_constraint(:membership, name: "user_group_membership_member_id_group_id_index")
  end
end

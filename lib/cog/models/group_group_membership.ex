defmodule Cog.Models.GroupGroupMembership do
  use Cog.Model
  alias Cog.Models.Group

  @primary_key false

  schema "group_group_membership" do
    belongs_to :member, Group, primary_key: true
    belongs_to :group, Group, primary_key: true
  end

  @required_fields ~w(member_id group_id)

  def changeset(model, params) do
    model
    |> cast(params, @required_fields)
    |> unique_constraint(:membership, name: "group_group_membership_member_id_group_id_index")
  end
end

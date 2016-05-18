defmodule Cog.Models.UserGroupMembership do
  use Cog.Model
  @primary_key false
  schema "user_group_membership" do
    belongs_to :member, Cog.Models.User, references: :id
    belongs_to :group, Cog.Models.Group, references: :id
  end

  @required_fields ~w(member_id group_id)

  def changeset(model, params) do
    model
    |> cast(params, @required_fields)
    |> unique_constraint(:membership, name: "user_group_membership_member_id_group_id_index")
  end
end

defimpl Poison.Encoder, for: Cog.Models.UserGroupMembership do
  def encode(struct, options) do
    map = struct
    |> Map.from_struct
    |> Map.take([:id, :member, :group])
    |> drop_not_loaded

    Poison.Encoder.Map.encode(map, options)
  end

  defp drop_not_loaded(%{member: %Ecto.Association.NotLoaded{}}=map) do
    Map.delete(map, :member)
    |> drop_not_loaded
  end
  defp drop_not_loaded(%{group: %Ecto.Association.NotLoaded{}}=map) do
    Map.delete(map, :group)
    |> drop_not_loaded
  end
  defp drop_not_loaded(map),
    do: map
end

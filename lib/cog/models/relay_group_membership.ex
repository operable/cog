defmodule Cog.Models.RelayGroupMembership do
  use Cog.Model
  @primary_key false

  schema "relay_group_memberships" do
    belongs_to :relay, Cog.Models.Relay, references: :id
    belongs_to :group, Cog.Models.RelayGroup, references: :id
  end

  @required_fields ~w(relay_id group_id)
  @optional_fields ~w()

  def changeset(model, params) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> unique_constraint(:membership, name: "relay_group_memberships_relay_id_group_id_index")
  end

end

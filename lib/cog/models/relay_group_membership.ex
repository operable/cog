defmodule Cog.Models.RelayGroupMembership do
  use Cog.Model
  alias Cog.Models.{Relay, RelayGroup}

  @primary_key false

  schema "relay_group_memberships" do
    belongs_to :relay, Relay, primary_key: true
    belongs_to :group, RelayGroup, primary_key: true
  end

  @required_fields ~w(relay_id group_id)
  @optional_fields ~w()

  def changeset(model, params) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> unique_constraint(:relay_id, name: :relay_group_memberships_relay_id_group_id_index)
  end

end

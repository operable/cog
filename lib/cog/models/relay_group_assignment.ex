defmodule Cog.Models.RelayGroupAssignment do
  use Cog.Model
  @primary_key false

  schema "relay_group_assignments" do
    belongs_to :bundle, Cog.Models.Bundle, references: :id
    belongs_to :group, Cog.Models.RelayGroup, references: :id
  end

  @required_fields ~w(bundle_id group_id)
  @optional_fields ~w()

  def changeset(model, params) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> unique_constraint(:bundle_id, name: :relay_group_assignments_bundle_id_group_id_index)
  end

end

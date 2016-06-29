defmodule Cog.Models.RelayGroupAssignment do
  use Cog.Model
  alias Cog.Models.{Bundle, RelayGroup}

  @primary_key false

  schema "relay_group_assignments" do
    belongs_to :bundle, Bundle, primary_key: true
    belongs_to :group, RelayGroup, primary_key: true
  end

  @required_fields ~w(bundle_id group_id)
  @optional_fields ~w()

  def changeset(model, params) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> foreign_key_constraint(:bundle_id, name: :relay_group_assignments_bundle_id_fkey)
    |> unique_constraint(:bundle_id, name: :relay_group_assignments_bundle_id_group_id_index)
  end

end

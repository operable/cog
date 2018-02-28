defmodule Cog.Models.RelayAssignment do
  use Cog.Model
  alias Cog.Models.{Bundle, Relay}

  @primary_key false

  schema "relay_assignments" do
    belongs_to :bundle, Bundle, primary_key: true
    belongs_to :relay, Relay, primary_key: true
  end

  @required_fields ~w(bundle_id relay_id)
  @optional_fields ~w()

  def changeset(model, params) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> foreign_key_constraint(:bundle_id, name: :relay_assignments_bundle_id_fkey)
    |> unique_constraint(:bundle_id, name: :relay_assignments_bundle_id_fkey)
  end
end

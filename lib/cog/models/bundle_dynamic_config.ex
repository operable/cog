defmodule Cog.Models.BundleDynamicConfig do
  use Cog.Model, :no_primary_key

  alias Cog.Util.Hash
  alias Cog.Models.Bundle

  schema "bundle_dynamic_configs" do
    field :layer, :string
    field :name, :string
    field :config, :map
    field :hash, :string

    belongs_to :bundle, Bundle, [foreign_key: :bundle_id]

    timestamps

  end

  @required_fields ~w(bundle_id layer name config)
  @optional_fields ~w()

  def changeset(model, params \\ :empty) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> validate_inclusion(:layer, ["base", "room", "user"])
    |> unique_constraint(:bundle_id, name: :bundle_dynamic_configs_bundle_id_index)
    |> calculate_hash
  end

  defp calculate_hash(changeset) do
    case fetch_change(changeset, :config) do
      :error ->
        changeset
      {:ok, config} ->
        put_change(changeset, :hash, Hash.compute_hash(config))
    end
  end

end

defmodule Cog.Repo.Migrations.LayeredDynamicConfig do
  use Ecto.Migration

  def change do

    # Add layer and name columns; all configs present now are base
    # configs, by definition.
    alter table(:bundle_dynamic_configs) do
      add :layer, :text, null: false, default: "base"
      add :name, :text, null: false, default: "config"
    end

    # Ensure that if layer is "base", name must be "config"; there's
    # only ever one "base" layer for a bundle
    create constraint(:bundle_dynamic_configs, "base_name_must_be_config", check: "CASE WHEN layer = 'base' THEN name = 'config' END")

    # bundle / layer / name must be unique
    drop unique_index(:bundle_dynamic_configs, [:bundle_id])
    create unique_index(:bundle_dynamic_configs, [:bundle_id, :layer, :name])

    # Remove defaults now that everything has been moved
    alter table(:bundle_dynamic_configs) do
      modify :layer, :text, default: nil
      modify :name, :text, default: nil
    end

  end
end

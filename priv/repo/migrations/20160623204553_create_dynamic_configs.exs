defmodule Cog.Repo.Migrations.CreateDynamicConfigs do
  use Ecto.Migration

  def change do
    create table(:bundle_dynamic_configs, primary_key: false) do
      add :bundle_id, references(:bundles_v2, type: :uuid, on_delete: :delete_all), null: false
      add :config, :map, null: false
      add :hash, :text, null: false

      timestamps
    end
    create unique_index(:bundle_dynamic_configs, [:bundle_id])
  end
end

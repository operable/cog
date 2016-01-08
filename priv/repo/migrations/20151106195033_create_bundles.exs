defmodule Cog.Repo.Migrations.CreateBundles do
  use Ecto.Migration

  def change do
    create table(:bundles, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :text, null: false
      add :config_file, :json, null: false
      add :manifest_file, :json, null: false

      timestamps
    end

    create unique_index(:bundles, [:name])
  end
end

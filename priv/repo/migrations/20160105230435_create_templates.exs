defmodule Cog.Repo.Migrations.CreateTemplates do
  use Ecto.Migration

  def change do
    create table(:templates, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :bundle_id, references(:bundles, type: :uuid, on_delete: :delete_all), null: false
      add :adapter, :string, null: false
      add :name, :string, null: false
      add :source, :text, null: false

      timestamps
    end

    create unique_index(:templates, [:bundle_id, :adapter, :name])
  end
end

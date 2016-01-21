defmodule Cog.Repo.Migrations.BundleStatus do
  use Ecto.Migration

  def change do
    alter table(:bundles) do
      add :enabled, :boolean, default: true
    end
  end
end

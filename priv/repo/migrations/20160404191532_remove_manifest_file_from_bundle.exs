defmodule Cog.Repo.Migrations.RemoveManifestFileFromBundle do
  use Ecto.Migration

  def change do
    alter table(:bundles) do
      remove :manifest_file
    end
  end
end

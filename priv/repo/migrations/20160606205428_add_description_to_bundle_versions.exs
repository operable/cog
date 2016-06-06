defmodule Cog.Repo.Migrations.AddDescriptionToBundleVersions do
  use Ecto.Migration

  def change do
    alter table(:bundle_versions_v2) do
      add :description, :text
    end
  end
end

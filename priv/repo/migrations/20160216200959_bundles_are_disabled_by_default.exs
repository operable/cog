defmodule Cog.Repo.Migrations.BundlesAreDisabledByDefault do
  use Ecto.Migration

  def change do
    alter table(:bundles) do
      modify :enabled, :boolean, default: false
    end
  end
end

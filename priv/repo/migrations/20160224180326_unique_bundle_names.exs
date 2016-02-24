defmodule Cog.Repo.Migrations.UniqueBundleNames do
  use Ecto.Migration

  def change do
    create unique_index(:bundles, [:name])
  end
end

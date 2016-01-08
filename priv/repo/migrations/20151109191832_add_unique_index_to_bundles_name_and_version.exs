defmodule Cog.Repo.Migrations.AddUniqueIndexToBundlesNameAndVersion do
  use Ecto.Migration

  def change do
    drop unique_index(:bundles, [:name])
  end
end

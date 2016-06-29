defmodule Cog.Repo.Migrations.RemovePreBundleVersionTables do
  use Ecto.Migration

  def change do
    drop table(:permissions)
    drop table(:namespaces)
    drop table(:rules)
    drop table(:commands)
    drop table(:bundles)
  end
end

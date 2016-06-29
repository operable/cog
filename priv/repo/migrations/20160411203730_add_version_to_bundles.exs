defmodule Cog.Repo.Migrations.AddVersionToBundles do
  use Ecto.Migration

  def change do
    alter table(:bundles) do
      add :version, :string
    end

    execute("UPDATE bundles SET version = '0.0.1'")

    alter table(:bundles) do
      modify :version, :string, null: false
    end
  end
end

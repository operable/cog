defmodule Cog.Repo.Migrations.CreatePermissions do
  use Ecto.Migration

  def change do
    create table(:permissions, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :namespace, :text, null: false # TODO Make this refer to a permission namespace table
      add :name, :text, null: false
    end

    create unique_index(:permissions, [:namespace, :name])
  end
end

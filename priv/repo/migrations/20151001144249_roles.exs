defmodule Cog.Repo.Migrations.Roles do
  use Ecto.Migration

  def change do
    create table(:roles, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :text, null: false
    end
    create unique_index(:roles, [:name])
  end
end

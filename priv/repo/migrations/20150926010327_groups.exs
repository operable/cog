defmodule Cog.Repo.Migrations.Groups do
  use Ecto.Migration

  def change do
    create table(:groups, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :text, null: false
    end
    create unique_index(:groups, [:name])
  end
end

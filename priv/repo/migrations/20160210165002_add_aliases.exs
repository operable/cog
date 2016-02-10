defmodule Cog.Repo.Migrations.AddAliases do
  use Ecto.Migration

  def change do
    create table(:site_command_aliases, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string, null: false
      add :pipeline, :text, null: false

      timestamps
    end
    create unique_index(:site_command_aliases, [:name])

    create table(:user_command_aliases, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string, null: false
      add :user_id, references(:users, type: :uuid), null: false
      add :pipeline, :text, null: false

      timestamps
    end
    create unique_index(:user_command_aliases, [:name, :user_id])
  end
end

defmodule Cog.Repo.Migrations.CommandDataModel do
  use Ecto.Migration

  def change do
    create table(:commands, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :text, null: false
      add :version, :text, null: false
    end
    create unique_index(:commands, [:name])

    create table(:rules, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :command_id, references(:commands, type: :uuid, on_delete: :delete_all, ), null: false
      add :score, :int, null: false
      add :parse_tree, :text, null: false
    end
    create unique_index(:rules, [:command_id, :parse_tree])

    create table(:rule_permissions, primary_key: false) do
      add :rule_id, references(:rules, type: :uuid, on_delete: :delete_all), null: false
      add :permission_id, references(:permissions, type: :uuid, on_delete: :delete_all), null: false
    end
    create unique_index(:rule_permissions, [:rule_id, :permission_id])
  end
end

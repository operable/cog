defmodule Cog.Repo.Migrations.Tokens do
  use Ecto.Migration

  def change do
    create table(:tokens, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all, null: false)
      add :value, :string, null: false
      timestamps
    end
    create unique_index(:tokens, [:user_id, :value])
  end
end

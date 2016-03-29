defmodule Cog.Repo.Migrations.AddRelays do
  use Ecto.Migration

  def change do
    create table(:relays, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :text, null: false
      add :token_digest, :text, null: false
      add :enabled, :boolean, null: false
      add :desc, :text, null: true

      timestamps
    end
    create unique_index(:relays, [:name])
  end
end

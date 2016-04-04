defmodule Cog.Repo.Migrations.EventHooks do
  use Ecto.Migration

  def change do
    create table(:event_hooks, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :name, :text, null: false
      add :pipeline, :text, null: false
      add :as_user, :text, null: true
      add :timeout_sec, :integer, null: true
      add :active, :boolean, null: false, default: true
      add :description, :text, null: true

      timestamps
    end

    create unique_index(:event_hooks, [:name])
  end

end

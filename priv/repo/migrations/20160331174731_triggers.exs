defmodule Cog.Repo.Migrations.Triggers do
  use Ecto.Migration

  def change do
    create table(:triggers, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :name, :text, null: false
      add :pipeline, :text, null: false
      add :as_user, :text, null: true
      add :timeout_sec, :integer, null: true
      add :active, :boolean, null: false, default: true
      add :description, :text, null: true

      timestamps
    end

    create unique_index(:triggers, [:name])
  end

end

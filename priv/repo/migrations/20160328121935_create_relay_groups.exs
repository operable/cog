defmodule Cog.Repo.Migrations.CreateRelayGroups do
  use Ecto.Migration

  def change do
    create table(:relay_groups, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :text, null: false
      add :desc, :text, null: true

      timestamps
    end
    create unique_index(:relay_groups, [:name])

    create table(:relay_group_memberships, primary_key: false) do
      add :relay_id, references(:relays, type: :uuid, on_delete: :delete_all), null: false
      add :group_id, references(:relay_groups, type: :uuid, on_delete: :delete_all), null: false
    end
    create unique_index(:relay_group_memberships, [:relay_id, :group_id])

  end

end

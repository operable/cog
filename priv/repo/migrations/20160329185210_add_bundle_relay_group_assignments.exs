defmodule Cog.Repo.Migrations.AddBundleRelayGroupAssignments do
  use Ecto.Migration

  def change do
    create table(:relay_group_assignments, primary_key: false) do
      add :bundle_id, references(:bundles, type: :uuid, on_delete: :delete_all), null: false
      add :group_id, references(:relay_groups, type: :uuid, on_delete: :delete_all), null: false
    end
    create unique_index(:relay_group_assignments, [:bundle_id, :group_id])
  end
end

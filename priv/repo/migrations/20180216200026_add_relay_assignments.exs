defmodule Cog.Repo.Migrations.AddRelayAssignments do
  use Ecto.Migration

  def up do
    create table(:relay_assignments, primary_key: false) do
      add :bundle_id, references(:bundles, type: :uuid, on_delete: :delete_all), null: false
      add :relay_id, references(:relays, type: :uuid, on_delete: :delete_all), null: false
    end
    create unique_index(:relay_assignments, [:bundle_id, :relay_id])

    qry = """
      INSERT INTO relay_assignments
        SELECT b.id AS bundle_id, r.id AS relay_id FROM bundles b
          JOIN relay_group_assignments a ON b.id = a.bundle_id
          JOIN relay_group_memberships m ON a.group_id = m.group_id
          JOIN relays r ON m.relay_id = r.id

    """
    Ecto.Adapters.SQL.query!(Cog.Repo, qry, [])
  end

  def down do
    drop table(:relay_assignments)
  end
end

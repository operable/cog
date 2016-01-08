defmodule Bishop.Repo.Migrations.AddBundleIdToCommands do
  use Ecto.Migration

  def change do
    alter table(:commands) do
      add :bundle_id, references(:bundles, type: :uuid, on_delete: :delete_all), null: false
    end
  end
end

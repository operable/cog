defmodule Cog.Repo.Migrations.AssociateNamespaceWithBundle do
  use Ecto.Migration

  def change do
    alter table(:namespaces) do
      add :bundle_id, references(:bundles, type: :uuid, on_delete: :delete_all), null: true # for site namespace, for now
    end
  end
end

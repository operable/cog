defmodule Cog.Repo.Migrations.PermissionNamespace do
  use Ecto.Migration

  def change do
    create table(:namespaces, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :text, null: false
    end
    create unique_index(:namespaces, [:name])

    # This only really works because we're not installed anywhere
    # persistent yet. Otherwise, we'd be doing some more involved
    # migrations.
    alter table(:permissions) do
      remove :namespace
      add :namespace_id, references(:namespaces, type: :uuid, on_delete: :delete_all), null: false
    end
    create unique_index(:permissions, [:namespace_id, :name])

  end
end

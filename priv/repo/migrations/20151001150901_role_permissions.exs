defmodule Cog.Repo.Migrations.RolePermissions do
  use Ecto.Migration

  def change do
    create table(:role_permissions, primary_key: false) do
      add :role_id, references(:roles, type: :uuid, on_delete: :delete_all), null: false
      add :permission_id, references(:permissions, type: :uuid, on_delete: :delete_all), null: false
    end
    create unique_index(:role_permissions, [:role_id, :permission_id])
  end
end

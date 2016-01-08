defmodule Cog.Repo.Migrations.UserPermissionGrants do
  use Ecto.Migration

  def change do
    create table(:user_permissions, primary_key: false) do
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :permission_id, references(:permissions, type: :uuid, on_delete: :delete_all), null: false
    end
    create unique_index(:user_permissions, [:user_id, :permission_id])
  end
end

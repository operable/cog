defmodule Cog.Repo.Migrations.GroupPermissionGrants do
  use Ecto.Migration

  def change do
    create table(:group_permissions, primary_key: false) do
      add :group_id, references(:groups, type: :uuid, on_delete: :delete_all), null: false
      add :permission_id, references(:permissions, type: :uuid, on_delete: :delete_all), null: false
    end
    create unique_index(:group_permissions, [:group_id, :permission_id])
  end

end

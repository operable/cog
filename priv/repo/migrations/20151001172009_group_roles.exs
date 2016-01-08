defmodule Cog.Repo.Migrations.GroupRoles do
  use Ecto.Migration

  def change do
    create table(:group_roles, primary_key: false) do
      add :group_id, references(:groups, type: :uuid, on_delete: :delete_all), null: false
      add :role_id, references(:roles, type: :uuid, on_delete: :delete_all), null: false
    end
    create unique_index(:group_roles, [:group_id, :role_id])
  end

end

defmodule Cog.Repo.Migrations.UserRoles do
  use Ecto.Migration

  def change do
    create table(:user_roles, primary_key: false) do
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :role_id, references(:roles, type: :uuid, on_delete: :delete_all), null: false
    end
    create unique_index(:user_roles, [:user_id, :role_id])
  end
end

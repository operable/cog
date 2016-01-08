defmodule Cog.Repo.Migrations.UserGroupMembership do
  use Ecto.Migration

  def change do
    create table(:user_group_membership, primary_key: false) do
      add :member_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :group_id, references(:groups, type: :uuid, on_delete: :delete_all), null: false
    end
    create unique_index(:user_group_membership, [:member_id, :group_id])
  end

end

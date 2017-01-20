defmodule Cog.Repo.Migrations.DropGroupGroupMembership do
  use Ecto.Migration

  def change do
    drop table(:group_group_membership)
  end
end

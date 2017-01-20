defmodule Cog.Repo.Migrations.DropGroupPermissions do
  use Ecto.Migration

  def change do
    drop table(:group_permissions)
  end
end

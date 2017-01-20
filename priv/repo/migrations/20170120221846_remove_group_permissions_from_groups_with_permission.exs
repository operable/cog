defmodule Cog.Repo.Migrations.RemoveGroupPermissionsFromGroupsWithPermission do
  use Ecto.Migration

  def up do
    execute """
    CREATE OR REPLACE FUNCTION groups_with_permission(
      p_permission permissions.id%TYPE)
    RETURNS SETOF groups.id%TYPE
    LANGUAGE SQL STABLE STRICT
    AS $$
      WITH RECURSIVE
      role_grants AS (
        SELECT gr.group_id
        FROM group_roles AS gr
        JOIN role_permissions AS rp
          USING (role_id)
        WHERE rp.permission_id = p_permission
      )
      SELECT group_id
       FROM role_grants;
    $$;
  """
  end

  def down do
    Code.eval_file("20170119212847_groups_with_permission_without_group_group_membership.exs", __DIR__)
    Cog.Repo.Migrations.GroupsWithPermissionWithoutGroupGroupMembership.up()
  end
end

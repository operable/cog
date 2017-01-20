defmodule Cog.Repo.Migrations.GroupsWithPermissionWithoutGroupGroupMembership do
  use Ecto.Migration

  def up do
    execute """
    CREATE OR REPLACE FUNCTION groups_with_permission(
      p_permission permissions.id%TYPE)
    RETURNS SETOF groups.id%TYPE
    LANGUAGE SQL STABLE STRICT
    AS $$
      WITH RECURSIVE
      direct_grants AS (
        SELECT group_id
        FROM group_permissions
        WHERE permission_id = p_permission
      ),
      role_grants AS (
        SELECT gr.group_id
        FROM group_roles AS gr
        JOIN role_permissions AS rp
          USING (role_id)
        WHERE rp.permission_id = p_permission
      ),
      in_groups AS (
        SELECT group_id FROM direct_grants
        UNION
        SELECT group_id FROM role_grants
      )
      SELECT group_id
       FROM in_groups;
    $$;
  """
  end

  def down do
    Code.eval_file("20160219160541_groups_with_permission.exs", __DIR__)
    Cog.Repo.Migrations.GroupsWithPermission.up()
  end
end

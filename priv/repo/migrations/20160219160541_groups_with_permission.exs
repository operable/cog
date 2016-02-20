defmodule Cog.Repo.Migrations.GroupsWithPermission do
  use Ecto.Migration

  def up do
    execute """
    CREATE FUNCTION groups_with_permission(
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
        UNION
        -- find all groups that are members of that group, etc.
        SELECT ggm.member_id
        FROM group_group_membership AS ggm
        JOIN in_groups AS ig
          USING (group_id)
      )
      SELECT group_id
       FROM in_groups;
    $$;
    """
  end

  def down do
    execute """
    DROP FUNCTION groups_with_permission(p_permission permissions.id%TYPE);
    """
  end
end

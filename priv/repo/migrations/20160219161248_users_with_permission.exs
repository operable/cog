defmodule Cog.Repo.Migrations.UsersWithPermission do
  use Ecto.Migration

  def up do
    execute """
    CREATE FUNCTION users_with_permission(
      p_permission permissions.id%TYPE)
    RETURNS SETOF users.id%TYPE
    LANGUAGE SQL STABLE STRICT
    AS $$
      WITH direct_grants AS (
        SELECT up.user_id
        FROM user_permissions AS up
        WHERE up.permission_id = p_permission
      ),
      role_grants AS (
        SELECT ur.user_id
        FROM user_roles AS ur
        JOIN role_permissions AS rp
          USING(role_id)
        WHERE rp.permission_id = p_permission
      ),
      all_groups AS (
        SELECT group_id
        FROM groups_with_permission(p_permission) AS g(group_id)
      ),
      group_grants AS (
        SELECT ugm.member_id AS user_id
        FROM user_group_membership AS ugm
        JOIN all_groups AS ag
          USING(group_id)
      )
      SELECT user_id FROM direct_grants
      UNION
      SELECT user_id FROM role_grants
      UNION
      SELECT user_id FROM group_grants
      ;
    $$;
    """
  end

  def down do
    execute "DROP FUNCTION users_with_permission(p_perm permissions.id%TYPE);"
  end
end

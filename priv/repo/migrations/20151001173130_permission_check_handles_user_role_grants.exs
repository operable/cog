defmodule Cog.Repo.Migrations.PermissionCheckHandlesUserRoleGrants do
  use Ecto.Migration

  def up do
    execute """
CREATE OR REPLACE FUNCTION user_has_permission(
  p_user users.id%TYPE,
  p_perm permissions.id%TYPE)
RETURNS BOOLEAN
LANGUAGE plpgsql STABLE STRICT
AS $$
DECLARE
  has_result uuid;
BEGIN
  -- Check to see if the actor has the permission directly
  SELECT up.permission_id FROM user_permissions AS up
   WHERE up.user_id = p_user
     AND up.permission_id = p_perm
    INTO has_result;

  -- If that returned anything, we're done
  IF has_result IS NOT NULL THEN
    RETURN TRUE;
  END IF;

  -- The user might have a role, though; check that!
  SELECT rp.permission_id
    FROM role_permissions AS rp
    JOIN user_roles AS ur
      ON rp.role_id = ur.role_id
   WHERE ur.user_id = p_user
     AND rp.permission_id = p_perm
    INTO has_result;

  -- If that returned anything, we're done
  IF has_result IS NOT NULL THEN
    RETURN TRUE;
  END IF;

  -- The permission wasn't granted directly to the user, we need
  -- to check the groups the user is in
  WITH all_groups AS (
    SELECT id FROM groups_for_user(p_user) AS g(id)
  ),
  group_permissions AS (
    SELECT gp.permission_id
      FROM group_permissions AS gp
      JOIN all_groups AS gfu
        ON gp.group_id = gfu.id
     WHERE gp.permission_id = p_perm
  ),
  group_role_permissions AS (
    SELECT rp.permission_id
      FROM role_permissions AS rp
      JOIN group_roles AS gr
        ON rp.role_id = gr.role_id
      JOIN all_groups AS ag
        ON gr.group_id = ag.id -- group_id, natural joins
     WHERE rp.permission_id = p_perm
  ),
  everything AS (
    SELECT permission_id FROM group_permissions
    UNION DISTINCT
    SELECT permission_id FROM group_role_permissions
  )
  SELECT permission_id
  FROM everything
  INTO has_result;

  -- If anything was found, we're done
  IF has_result IS NOT NULL THEN
    RETURN TRUE;
  END IF;

  -- The user doesn't have the permission
  RETURN FALSE;

END;
$$;
   """
  end

  def down do
    Code.eval_file("20150929174803_permission_check_handles_group_nesting.exs", __DIR__)
    Cog.Repo.Migrations.PermissionCheckHandlesGroupNesting.up()
  end
end

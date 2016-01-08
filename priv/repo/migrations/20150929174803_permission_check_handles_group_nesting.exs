defmodule Cog.Repo.Migrations.PermissionCheckHandlesGroupNesting do
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

  -- The permission wasn't granted directly to the user, we need
  -- to check the groups the user is in
  SELECT gp.permission_id
    FROM group_permissions AS gp
    JOIN groups_for_user(p_user) AS gfu(id)
      ON gp.group_id = gfu.id
   WHERE gp.permission_id = p_perm
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
    Code.eval_file("20150928155606_permission_check.exs", __DIR__)
    Cog.Repo.Migrations.PermissionCheck.up()
  end
end

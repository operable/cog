defmodule Cog.Repo.Migrations.PermissionCheck do
  use Ecto.Migration

  def up do
    execute """
CREATE OR REPLACE FUNCTION user_has_permission(
p_user users.id%TYPE,
       p_perm permissions.id%TYPE)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE -- <- this function doesn't alter the database; just queries it
STRICT -- <- returns NULL immediately if any arguments are NULL
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
         JOIN user_group_membership AS ugm
           ON gp.group_id = ugm.group_id
        WHERE ugm.member_id = p_user
          AND gp.permission_id = p_perm
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
    execute """
    DROP FUNCTION IF EXISTS user_has_permission(uuid, uuid);
    """
  end
end

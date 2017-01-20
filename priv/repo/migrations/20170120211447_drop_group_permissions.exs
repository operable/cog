defmodule Cog.Repo.Migrations.DropGroupPermissions do
  use Ecto.Migration

  def up do
    drop table(:group_permissions)

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

    execute """
    CREATE OR REPLACE FUNCTION fetch_user_permissions (
      p_user users.id%TYPE)
    RETURNS TABLE(id uuid, name text)
    LANGUAGE plpgsql STABLE STRICT
    AS $$
    BEGIN

    RETURN QUERY WITH

      -- Walk the tree of group memberships and find
      -- all the groups the user is a direct and
      -- indirect member of.
      all_groups as (
      SELECT group_id
        FROM groups_for_user(p_user)
      ),
      all_permissions as (

      -- Retrieve all permissions granted to the user
      -- via roles
      SELECT rp.permission_id
        FROM role_permissions as rp
        JOIN user_roles as ur
          ON rp.role_id = ur.role_id
        WHERE ur.user_id = p_user
      UNION DISTINCT

      -- Retrieve all permissions granted to the groups
      -- via roles
      SELECT rp.permission_id
        FROM role_permissions as rp
        JOIN group_roles as gr
          ON rp.role_id = gr.role_id
        JOIN all_groups AS ag
          ON gr.group_id = ag.group_id
      UNION DISTINCT

      -- Retrieve all permissions granted directly to the user
      SELECT up.permission_id
        FROM user_permissions as up
       WHERE up.user_id = p_user
      )

    -- Join the permission ids returned by the CTE against
    -- the permissions and namespaces tables to produce
    -- the final result
    SELECT p.id, b.name||':'||p.name as name
      FROM permissions as p, bundles as b, all_permissions as ap
     WHERE ap.permission_id = p.id and p.bundle_id = b.id;
    END;
    $$;
   """

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

end

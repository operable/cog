defmodule Cog.Repo.Migrations.DropUserPermsAndRoles do
  use Ecto.Migration

  def change do
    drop table(:user_permissions)

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
    CREATE OR REPLACE FUNCTION users_with_permission(
      p_permission permissions.id%TYPE)
    RETURNS SETOF users.id%TYPE
    LANGUAGE SQL STABLE STRICT
    AS $$
      WITH role_grants AS (
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
      SELECT user_id FROM role_grants
      UNION
      SELECT user_id FROM group_grants
      ;
    $$;
    """
  end
end

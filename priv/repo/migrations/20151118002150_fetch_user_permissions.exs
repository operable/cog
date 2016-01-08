defmodule Cog.Repo.Migrations.FetchUserPermissions do
  use Ecto.Migration

  def up do
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

  -- Retrieve all permissions granted to the list
  -- groups returned from all_groups
  SELECT gp.permission_id
    FROM group_permissions as gp
    JOIN all_groups as ag
      ON gp.group_id = ag.group_id
  UNION DISTINCT

  -- Retrieve all permissions granted to the user
  -- via roles
  SELECT rp.permission_id
    FROM role_permissions as rp
    JOIN user_roles as ur
      ON rp.role_id = ur.role_id
    WHERE ur.user_id = p_user
  UNION DISTINCT

  -- Retrieve all permissions granted directly to the user
  SELECT up.permission_id
    FROM user_permissions as up
   WHERE up.user_id = p_user
  )

-- Join the permission ids returned by the CTE against
-- the permissions and namespaces tables to produce
-- the final result
SELECT p.id, ns.name||':'||p.name as name
  FROM permissions as p, namespaces as ns, all_permissions as ap
 WHERE ap.permission_id = p.id and p.namespace_id = ns.id;
END;
$$;
   """
  end

  def down do
    execute "DROP FUNCTION fetch_user_permissions(users.username%TYPE)"
  end
end

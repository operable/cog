defmodule Cog.Repo.Migrations.RenameV2Tables do
  use Ecto.Migration

  def change do
    rename table(:bundle_versions_v2), to: table(:bundle_versions)
    execute "ALTER INDEX bundle_versions_v2_pkey RENAME TO bundle_versions_pkey"
    execute "ALTER INDEX bundle_versions_v2_bundle_id_version_index RENAME TO bundle_versions_bundle_id_version_index"
    execute "ALTER TABLE bundle_versions RENAME CONSTRAINT bundle_versions_v2_bundle_id_fkey TO bundle_versions_bundle_id_fkey"

    rename table(:bundles_v2), to: table(:bundles)
    execute "ALTER INDEX bundles_v2_pkey RENAME TO bundles_pkey"
    execute "ALTER INDEX bundles_v2_name_index RENAME TO bundles_name_index"

    rename table(:command_versions_v2), to: table(:command_versions)
    execute "ALTER INDEX command_versions_v2_pkey RENAME TO command_versions_pkey"
    execute "ALTER INDEX command_versions_v2_bundle_version_id_command_id_index RENAME TO command_versions_bundle_version_id_command_id_index"
    execute "ALTER TABLE command_versions RENAME CONSTRAINT command_versions_v2_bundle_version_id_fkey TO command_versions_bundle_version_id_fkey"
    execute "ALTER TABLE command_versions RENAME CONSTRAINT command_versions_v2_command_id_fkey TO command_versions_command_id_fkey"

    rename table(:commands_v2), to: table(:commands)
    execute "ALTER INDEX commands_v2_pkey RENAME TO commands_pkey"
    execute "ALTER INDEX commands_v2_bundle_id_name_index RENAME TO commands_bundle_id_name_index"
    execute "ALTER TABLE commands RENAME CONSTRAINT commands_v2_bundle_id_fkey TO commands_bundle_id_fkey"

    rename table(:permission_bundle_version_v2), to: table(:permission_bundle_version)
    execute "ALTER INDEX permission_bundle_version_v2_permission_id_bundle_version_id_in RENAME TO permission_bundle_version_permission_id_bundle_version_id_in"
    execute "ALTER TABLE permission_bundle_version RENAME CONSTRAINT permission_bundle_version_v2_bundle_version_id_fkey TO permission_bundle_version_bundle_version_id_fkey"
    execute "ALTER TABLE permission_bundle_version RENAME CONSTRAINT permission_bundle_version_v2_permission_id_fkey TO permission_bundle_version_permission_id_fkey"

    rename table(:permissions_v2), to: table(:permissions)
    execute "ALTER INDEX permissions_v2_pkey RENAME TO permissions_pkey"
    execute "ALTER INDEX permissions_v2_bundle_id_name_index RENAME TO permissions_bundle_id_name_index"
    execute "ALTER TABLE permissions RENAME CONSTRAINT permissions_v2_bundle_id_fkey TO permissions_bundle_id_fkey"

    rename table(:rule_bundle_version_v2), to: table(:rule_bundle_version)
    execute "ALTER INDEX rule_bundle_version_v2_rule_id_bundle_version_id_index RENAME TO rule_bundle_version_rule_id_bundle_version_id_index"
    execute "ALTER TABLE rule_bundle_version RENAME CONSTRAINT rule_bundle_version_v2_bundle_version_id_fkey TO rule_bundle_version_bundle_version_id_fkey"
    execute "ALTER TABLE rule_bundle_version RENAME CONSTRAINT rule_bundle_version_v2_rule_id_fkey TO rule_bundle_version_rule_id_fkey"

    rename table(:rules_v2), to: table(:rules)
    execute "ALTER INDEX rules_v2_pkey RENAME TO rules_pkey"
    execute "ALTER INDEX rules_v2_command_id_parse_tree_index RENAME TO rules_command_id_parse_tree_index"
    execute "ALTER TABLE rules RENAME CONSTRAINT rules_v2_command_id_fkey TO rules_command_id_fkey"

    execute """
    CREATE OR REPLACE FUNCTION protect_admin_role_permissions()
    RETURNS TRIGGER
    LANGUAGE plpgsql
    AS $$
    DECLARE
      role TEXT;
      bundle TEXT;
    BEGIN
      SELECT roles.name INTO role FROM roles WHERE roles.id=OLD.role_id;

      SELECT bundles.name
        INTO bundle
        FROM bundles, permissions
       WHERE bundles.id=permissions.bundle_id
         AND permissions.id=OLD.permission_id;

      IF role = '#{Cog.Util.Misc.admin_role}' AND bundle = '#{Cog.Util.Misc.embedded_bundle}' THEN
        RAISE EXCEPTION 'cannot remove embedded permissions from admin role';
      END IF;
      RETURN NULL;
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
  end
end

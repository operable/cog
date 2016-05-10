defmodule Cog.Repo.Migrations.BundleVersionSchema do
  use Ecto.Migration

  def change do
    create table(:bundles_v2, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :text, null: false
      timestamps
    end
    create unique_index(:bundles_v2, [:name])

    create table(:bundle_versions_v2, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :bundle_id, references(:bundles_v2, type: :uuid, on_delete: :delete_all), null: false
      add :version, {:array, :integer}, default: fragment("ARRAY[0,0,0]"), null: false
      add :config_file, :json, null: false
      timestamps
    end
    create unique_index(:bundle_versions_v2, [:bundle_id, :version])

    # create table(:enabled_bundles_v2, primary_key: false) do
    #   name
    #   version

    #   # Need a bundle name and a bundle version... how best to
    #   # engineer this?
    # end

    create table(:commands_v2, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :bundle_id, references(:bundles_v2, type: :uuid, on_delete: :delete_all), null: false
      add :name, :text, null: false
      timestamps
    end
    create unique_index(:commands_v2, [:bundle_id, :name])

    create table(:command_versions_v2, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :bundle_version_id, references(:bundle_versions_v2, type: :uuid, on_delete: :delete_all), null: false
      add :command_id, references(:commands_v2, type: :uuid, on_delete: :delete_all), null: false
      add :documentation, :text, null: true
      timestamps
    end
    create unique_index(:command_versions_v2, [:bundle_version_id, :command_id])

    create table(:rules_v2, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :command_id, references(:commands_v2, type: :uuid, on_delete: :delete_all, ), null: false
#      add :bundle_id, references(:bundles_v2, type: :uuid, on_delete: :delete_all, ), null: false
      add :parse_tree, :text, null: false
      add :score, :int, null: false
      add :enabled, :boolean, null: false, default: true
      timestamps
    end
#    create unique_index(:rules_v2, [:bundle_id, :command_id, :parse_tree])
    create unique_index(:rules_v2, [:command_id, :parse_tree])

    create table(:rule_bundle_version_v2, primary_key: false) do
      add :rule_id, references(:rules_v2, type: :uuid, on_delete: :delete_all, ), null: false
      add :bundle_version_id, references(:bundle_versions_v2, type: :uuid, on_delete: :delete_all), null: false
    end
    # TODO: Wants to be a primary key
    create unique_index(:rule_bundle_version_v2, [:rule_id, :bundle_version_id])

    create table(:permissions_v2, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :bundle_id, references(:bundles_v2, type: :uuid, on_delete: :delete_all), null: false
      add :name, :text, null: false
      timestamps
    end
    create unique_index(:permissions_v2, [:bundle_id, :name])

    create table(:permission_bundle_version_v2, primary_key: false) do
      add :permission_id, references(:permissions_v2, type: :uuid, on_delete: :delete_all, ), null: false
      add :bundle_version_id, references(:bundle_versions_v2, type: :uuid, on_delete: :delete_all), null: false
    end
    # TODO: Wants to be a primary key
    create unique_index(:permission_bundle_version_v2, [:permission_id, :bundle_version_id])

    ########################################################################
    # MOVE THE DATA OVER
    ########################################################################

    # Works in docker images; pgcrypto does too, FWIW
    # docker exec -it $(docker-compose ps -q postgres) psql -U cog -c 'CREATE EXTENSION IF NOT EXISTS "uuid-ossp"'
    execute """
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp"
    """

    # Turn all namespaces into bundles. All namespaces except 'site' are
    # associated with an existing bundle. Use that bundle ID as the new
    # bundle ID, but generate a new one for 'site'
    execute """
    INSERT INTO bundles_v2(id, name, inserted_at, updated_at)
    SELECT COALESCE(id, uuid_generate_v4()), name, now(), now()
    FROM namespaces
    """

    # insert into permissions
    # values(uuid_generate_v4(), 'monkeys', 'e901f3cd-ffe6-464f-86bd-f35b84f17373');

    # Move all permissions over, preserving their IDs, but shifting their
    # old namespace IDs over to their new bundle IDs. Includes fallback
    # logic for any site permissions
    execute """
    INSERT INTO permissions_v2(id, bundle_id, name, inserted_at, updated_at)
    SELECT p.id, COALESCE(n.id, backup.id), p.name, now(), now()
      FROM permissions AS p
      JOIN namespaces AS n
        ON p.namespace_id = n.id
      JOIN bundles_v2 AS backup
        ON n.name = backup.name
    """

    # move existing bundles into versioned bundles. Assumes all configs
    # have a `version` field, though

    execute """
    INSERT INTO bundle_versions_v2(id, bundle_id, version, config_file, inserted_at, updated_at)
    SELECT b.id,
           bundles_v2.id,
           regexp_split_to_array(ltrim(rtrim((b.config_file->'version')::text, '"'), '"'), '\\.')::int[],
           b.config_file,
           now(),
           now()
    FROM bundles AS b
    JOIN bundles_v2
      ON b.name = bundles_v2.name
    """

    # Create a site bundle version
    execute """
    INSERT INTO bundle_versions_v2(id, bundle_id, version, config_file, inserted_at, updated_at)
    SELECT uuid_generate_v4(),
           b_v2.id,
           '{0,0,0}',
           '{}',
           now(),
           now()
    FROM bundles_v2 AS b_v2
    WHERE b_v2.name = 'site'
    """

    # TODO: Need to add code that only allows one version of site bundle

    # Record commands and the bundles they're associated with
    execute """
    INSERT INTO commands_v2(id, bundle_id, name, inserted_at, updated_at)
    SELECT c.id,
           b_v2.id,
           c.name,
           now(),
           now()
    FROM commands AS c
    JOIN bundle_versions_v2 AS bv
      ON c.bundle_id = bv.id
    JOIN bundles_v2 AS b_v2
      ON b_v2.id = bv.bundle_id
    """

    # Create command version instances; a command's version is equivalent
    # to its bundle's version
    execute """
    INSERT INTO command_versions_v2(id, bundle_version_id, command_id, documentation, inserted_at, updated_at)
    SELECT uuid_generate_v4(),
           bv.id,
           c_v2.id,
           c.documentation,
           now(),
           now()
    FROM commands AS c
    JOIN bundle_versions_v2 AS bv
      ON c.bundle_id = bv.id
    JOIN commands_v2 AS c_v2
      ON c.id = c_v2.id
    """

    ########################################################################

    # Link permissions to bundle VERSIONS
    execute """
    DO $$
    DECLARE
        bv bundle_versions_v2%ROWTYPE;
        permission text[];
    BEGIN
        FOR bv IN SELECT * FROM bundle_versions_v2 LOOP
          FOR permission IN SELECT regexp_split_to_array(p, E':')
              FROM (SELECT json_array_elements_text(bv.config_file->'permissions')) AS perms(p) LOOP

              INSERT INTO permission_bundle_version_v2(permission_id, bundle_version_id)
              SELECT p.id, bv.id
              FROM permissions_v2 AS p
              JOIN bundles_v2 AS b_v2
                ON p.bundle_id = b_v2.id
              WHERE b_v2.id = bv.bundle_id
                AND p.name = permission[2];

          END LOOP;
        END LOOP;
    END;
    $$;
    """

    # Handle site permissions special
    execute """
    INSERT INTO permission_bundle_version_v2(permission_id, bundle_version_id)
    SELECT p_v2.id, bv.id
      FROM permissions_v2 AS p_v2
      JOIN bundles_v2 AS b_v2
        ON p_v2.bundle_id = b_v2.id
      JOIN bundle_versions_v2 AS bv
        ON bv.bundle_id = b_v2.id
    WHERE b_v2.name = 'site'
    """

    # Need to re-link permissions to authz tables!
    execute """
    ALTER TABLE role_permissions
    DROP CONSTRAINT role_permissions_permission_id_fkey;
    """

    execute """
    ALTER TABLE role_permissions
    ADD CONSTRAINT role_permissions_permission_id_fkey FOREIGN KEY(permission_id) REFERENCES permissions_v2(id) ON DELETE CASCADE;
    """

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

      SELECT bundles_v2.name
        INTO bundle
        FROM bundles_v2, permissions_v2
       WHERE bundles_v2.id=permissions_v2.bundle_id
         AND permissions_v2.id=OLD.permission_id;

      IF role = '#{Cog.admin_role}' AND bundle = '#{Cog.embedded_bundle}' THEN
        RAISE EXCEPTION 'cannot remove embedded permissions from admin role';
      END IF;
      RETURN NULL;
    END;
    $$;
    """

    # Move command options over
    execute "ALTER TABLE command_options DROP CONSTRAINT command_options_command_id_fkey"
    execute "ALTER TABLE command_options ADD CONSTRAINT command_options_command_id_fkey FOREIGN KEY(command_id) REFERENCES commands_v2(id) ON DELETE CASCADE"

    # Move templates over
    execute "ALTER TABLE templates DROP CONSTRAINT templates_bundle_id_fkey"
    execute "ALTER TABLE templates ADD CONSTRAINT templates_bundle_id_fkey FOREIGN KEY (bundle_id) REFERENCES bundle_versions_v2(id) ON DELETE CASCADE"
    execute "ALTER TABLE templates RENAME bundle_id TO bundle_version_id;"

    # Updated relay_group_assignments
    execute "ALTER TABLE relay_group_assignments DROP CONSTRAINT relay_group_assignments_bundle_id_fkey;"

    execute """
    UPDATE relay_group_assignments AS rga
    SET bundle_id = b_v2.id
    FROM bundles_v2 AS b_v2,
         bundle_versions_v2 AS bv
    WHERE rga.bundle_id = bv.id
      AND b_v2.id = bv.bundle_id
    """

    execute """
    ALTER TABLE relay_group_assignments
    ADD CONSTRAINT relay_group_assignments_bundle_id_fkey FOREIGN KEY(bundle_id) REFERENCES bundles_v2(id) ON UPDATE CASCADE ON DELETE CASCADE
    """

    execute """
    INSERT INTO rules_v2(id, command_id, parse_tree, score, enabled, inserted_at, updated_at)
    SELECT id, command_id, parse_tree, score, true, now(), now()
    FROM rules
    """

    # Link new rules and new permissions
    execute """
    ALTER table rule_permissions
    DROP CONSTRAINT rule_permissions_rule_id_fkey
    """
    execute """
    ALTER TABLE rule_permissions
    ADD CONSTRAINT rule_permissions_rule_id_fkey
    FOREIGN KEY(rule_id) REFERENCES rules_v2(id) ON DELETE CASCADE ON UPDATE CASCADE
    """
    execute """
    ALTER table rule_permissions
    DROP CONSTRAINT rule_permissions_permission_id_fkey
    """
    execute """
    ALTER TABLE rule_permissions
    ADD CONSTRAINT rule_permissions_permission_id_fkey
    FOREIGN KEY(permission_id) REFERENCES permissions_v2(id) ON DELETE CASCADE ON UPDATE CASCADE
    """

  end
end

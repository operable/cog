defmodule Cog.Repo.Migrations.ProtectAdminRoleAndGroup do
  use Ecto.Migration

  def up do
    execute """
CREATE OR REPLACE FUNCTION protect_admin_role()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF OLD.NAME = '#{Cog.admin_role}' THEN
    RAISE EXCEPTION 'cannot modify admin role';
  END IF;
  RETURN NULL;
END;
$$;
"""
    execute """
CREATE CONSTRAINT TRIGGER protect_admin_role
AFTER UPDATE OR DELETE
ON roles
FOR EACH ROW
EXECUTE PROCEDURE protect_admin_role();
"""

    execute """
CREATE OR REPLACE FUNCTION protect_admin_group()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF OLD.NAME = '#{Cog.admin_group}' THEN
    RAISE EXCEPTION 'cannot modify admin group';
  END IF;
  RETURN NULL;
END;
$$;
"""
    execute """
CREATE CONSTRAINT TRIGGER protect_admin_group
AFTER UPDATE OR DELETE
ON groups
FOR EACH ROW
EXECUTE PROCEDURE protect_admin_group();
"""

      execute """
CREATE OR REPLACE FUNCTION protect_embedded_bundle()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF OLD.NAME = '#{Cog.embedded_bundle}' THEN
    RAISE EXCEPTION 'cannot modify embedded bundle';
  END IF;
  RETURN NULL;
END;
$$;
"""
    execute """
CREATE CONSTRAINT TRIGGER protect_embedded_bundle
AFTER UPDATE OR DELETE
ON bundles
FOR EACH ROW
EXECUTE PROCEDURE protect_embedded_bundle();
"""
  end

  def down do
    execute "DROP TRIGGER protect_admin_role ON roles;"
    execute "DROP FUNCTION protect_admin_role();"
    execute "DROP TRIGGER protect_admin_group ON groups;"
    execute "DROP FUNCTION protect_admin_group();"
    execute "DROP TRIGGER protect_embedded_bundle ON bundles;"
    execute "DROP FUNCTION protect_embedded_bundle();"
  end
end

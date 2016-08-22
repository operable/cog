defmodule Cog.Repo.Migrations.ProtectAdminRolePermissions do
  use Ecto.Migration

  def up do
    execute """
CREATE OR REPLACE FUNCTION protect_admin_role_permissions()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  role TEXT;
  namespace TEXT;
BEGIN
  SELECT roles.name INTO role FROM roles WHERE roles.id=OLD.role_id;

  SELECT namespaces.name
    INTO namespace
    FROM namespaces, permissions
   WHERE namespaces.id=permissions.namespace_id
     AND permissions.id=OLD.permission_id;

  IF role = '#{Cog.Util.Misc.admin_role}' AND namespace = '#{Cog.Util.Misc.embedded_bundle}' THEN
    RAISE EXCEPTION 'cannot remove embedded permissions from admin role';
  END IF;
  RETURN NULL;
END;
$$;
"""
    execute """
CREATE CONSTRAINT TRIGGER protect_admin_role_permissions
AFTER UPDATE OR DELETE
ON role_permissions
FOR EACH ROW
EXECUTE PROCEDURE protect_admin_role_permissions();
"""
  end

  def down do
    execute "DROP TRIGGER protect_admin_role_permissions ON role_permissions;"
    execute "DROP FUNCTION protect_admin_role_permissions();"
  end

end

defmodule Cog.Repo.Migrations.ProtectAdminGroupMembership do
  use Ecto.Migration

  def up do
    execute """
    CREATE OR REPLACE FUNCTION protect_admin_group_membership()
    RETURNS TRIGGER
    LANGUAGE plpgsql
    AS $$
    DECLARE
      admin_member_id     uuid;
      cog_admin_group_id  uuid;
    BEGIN
      SELECT id INTO admin_member_id
      FROM users
      WHERE username = 'admin';

      SELECT id INTO cog_admin_group_id
      FROM groups
      WHERE name = 'cog-admin';

      IF OLD.member_id = admin_member_id AND OLD.group_id = cog_admin_group_id THEN
        RAISE EXCEPTION 'cannot remove admin user from cog-admin group';
      END IF;
      RETURN NULL;
    END;
    $$;
    """

    execute """
    CREATE CONSTRAINT TRIGGER protect_admin_group_membership
    AFTER UPDATE OR DELETE
    ON user_group_membership
    FOR EACH ROW
    EXECUTE PROCEDURE protect_admin_group_membership();
    """
  end

  def down do
    execute """
    DROP TRIGGER protect_admin_group_membership ON user_group_membership;
    """

    execute """
    DROP FUNCTION protect_admin_group_membership();
    """
  end
end

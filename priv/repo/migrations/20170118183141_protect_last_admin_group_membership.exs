defmodule Cog.Repo.Migrations.ProtectLastAdminGroupMembership do
  use Ecto.Migration

  def up do
    execute """
    DROP TRIGGER protect_admin_group_membership ON user_group_membership;
    """

    execute """
    DROP FUNCTION protect_admin_group_membership();
    """

    execute """
    CREATE OR REPLACE FUNCTION protect_admin_group_membership()
    RETURNS TRIGGER
    LANGUAGE plpgsql
    AS $$
    DECLARE
      cog_admin_membership_count int;
      cog_admin_group_id         uuid;
    BEGIN
      SELECT id INTO cog_admin_group_id
      FROM groups
      WHERE name = 'cog-admin';

      SELECT count(*) INTO cog_admin_membership_count
      FROM user_group_membership
      WHERE group_id = cog_admin_group_id;

      IF OLD.group_id = cog_admin_group_id AND cog_admin_membership_count = 0 THEN
        RAISE EXCEPTION 'cannot remove last user from cog-admin group';
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
end

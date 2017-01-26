defmodule Cog.Repo.Migrations.ConvertCascadeReferencesToRestrict do
  use Ecto.Migration

  def up do
    execute "ALTER TABLE group_roles DROP CONSTRAINT group_roles_group_id_fkey"
    execute "ALTER TABLE group_roles ADD CONSTRAINT group_roles_group_id_fkey FOREIGN KEY (group_id) REFERENCES groups(id) ON UPDATE CASCADE ON DELETE RESTRICT"

    execute "ALTER TABLE group_roles DROP CONSTRAINT group_roles_role_id_fkey"
    execute "ALTER TABLE ONLY group_roles ADD CONSTRAINT group_roles_role_id_fkey FOREIGN KEY (role_id) REFERENCES roles(id) ON UPDATE CASCADE ON DELETE RESTRICT"

    execute "ALTER TABLE relay_group_assignments DROP CONSTRAINT relay_group_assignments_group_id_fkey"
    execute "ALTER TABLE ONLY relay_group_assignments ADD CONSTRAINT relay_group_assignments_group_id_fkey FOREIGN KEY (group_id) REFERENCES relay_groups(id) ON UPDATE CASCADE ON DELETE RESTRICT"

    execute "ALTER TABLE relay_group_memberships DROP CONSTRAINT relay_group_memberships_group_id_fkey"
    execute "ALTER TABLE ONLY relay_group_memberships ADD CONSTRAINT relay_group_memberships_group_id_fkey FOREIGN KEY (group_id) REFERENCES relay_groups(id) ON UPDATE CASCADE ON DELETE RESTRICT"

    execute "ALTER TABLE relay_group_memberships DROP CONSTRAINT relay_group_memberships_relay_id_fkey"
    execute "ALTER TABLE ONLY relay_group_memberships ADD CONSTRAINT relay_group_memberships_relay_id_fkey FOREIGN KEY (relay_id) REFERENCES relays(id) ON UPDATE CASCADE ON DELETE RESTRICT"

    execute "ALTER TABLE role_permissions DROP CONSTRAINT role_permissions_permission_id_fkey"
    execute "ALTER TABLE ONLY role_permissions ADD CONSTRAINT role_permissions_permission_id_fkey FOREIGN KEY (permission_id) REFERENCES permissions(id) ON UPDATE CASCADE ON DELETE RESTRICT"

    execute "ALTER TABLE role_permissions DROP CONSTRAINT role_permissions_role_id_fkey"
    execute "ALTER TABLE ONLY role_permissions ADD CONSTRAINT role_permissions_role_id_fkey FOREIGN KEY (role_id) REFERENCES roles(id) ON UPDATE CASCADE ON DELETE RESTRICT"

    execute "ALTER TABLE user_group_membership DROP CONSTRAINT user_group_membership_group_id_fkey"
    execute "ALTER TABLE ONLY user_group_membership ADD CONSTRAINT user_group_membership_group_id_fkey FOREIGN KEY (group_id) REFERENCES groups(id) ON UPDATE CASCADE ON DELETE RESTRICT"

    execute "ALTER TABLE user_group_membership DROP CONSTRAINT user_group_membership_member_id_fkey"
    execute "ALTER TABLE ONLY user_group_membership ADD CONSTRAINT user_group_membership_member_id_fkey FOREIGN KEY (member_id) REFERENCES users(id) ON UPDATE CASCADE ON DELETE RESTRICT"
  end

  def down do
    execute "ALTER TABLE group_roles DROP CONSTRAINT group_roles_group_id_fkey"
    execute "ALTER TABLE group_roles ADD CONSTRAINT group_roles_group_id_fkey FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE"

    execute "ALTER TABLE group_roles DROP CONSTRAINT group_roles_role_id_fkey"
    execute "ALTER TABLE ONLY group_roles ADD CONSTRAINT group_roles_role_id_fkey FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE"

    execute "ALTER TABLE relay_group_assignments DROP CONSTRAINT relay_group_assignments_group_id_fkey"
    execute "ALTER TABLE ONLY relay_group_assignments ADD CONSTRAINT relay_group_assignments_group_id_fkey FOREIGN KEY (group_id) REFERENCES relay_groups(id) ON DELETE CASCADE"

    execute "ALTER TABLE relay_group_memberships DROP CONSTRAINT relay_group_memberships_group_id_fkey"
    execute "ALTER TABLE ONLY relay_group_memberships ADD CONSTRAINT relay_group_memberships_group_id_fkey FOREIGN KEY (group_id) REFERENCES relay_groups(id) ON DELETE CASCADE"

    execute "ALTER TABLE relay_group_memberships DROP CONSTRAINT relay_group_memberships_relay_id_fkey"
    execute "ALTER TABLE ONLY relay_group_memberships ADD CONSTRAINT relay_group_memberships_relay_id_fkey FOREIGN KEY (relay_id) REFERENCES relays(id) ON DELETE CASCADE"

    execute "ALTER TABLE role_permissions DROP CONSTRAINT role_permissions_permission_id_fkey"
    execute "ALTER TABLE ONLY role_permissions ADD CONSTRAINT role_permissions_permission_id_fkey FOREIGN KEY (permission_id) REFERENCES permissions(id) ON DELETE CASCADE"

    execute "ALTER TABLE role_permissions DROP CONSTRAINT role_permissions_role_id_fkey"
    execute "ALTER TABLE ONLY role_permissions ADD CONSTRAINT role_permissions_role_id_fkey FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE"

    execute "ALTER TABLE user_group_membership DROP CONSTRAINT user_group_membership_group_id_fkey"
    execute "ALTER TABLE ONLY user_group_membership ADD CONSTRAINT user_group_membership_group_id_fkey FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE"

    execute "ALTER TABLE user_group_membership DROP CONSTRAINT user_group_membership_member_id_fkey"
    execute "ALTER TABLE ONLY user_group_membership ADD CONSTRAINT user_group_membership_member_id_fkey FOREIGN KEY (member_id) REFERENCES users(id) ON DELETE CASCADE"
  end
end

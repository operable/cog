defmodule RoleTest do
  use Cog.ModelCase
  alias Cog.Models.Role

  setup do
    {:ok, [role: role("admin"),
           permission: permission("test:do_stuff"),
           group: group("test_group")]}
  end

  test "permissions may be granted to roles", %{role: role, permission: permission} do
    :ok = Permittable.grant_to(role, permission)
    assert_permission_is_granted(role, permission)
  end

  test "adding a permission to a role is idempotent", %{role: role, permission: permission} do
    :ok = Permittable.grant_to(role, permission)
    assert(:ok = Permittable.grant_to(role, permission))
  end

  test "deleting a role granted to a group", %{role: role, group: group} do
    :ok = Permittable.grant_to(group, role)
    changeset = Role.changeset(role, %{})
    assert {:error, changeset} = Repo.delete(changeset)
    assert [id: {"cannot delete role that has been granted to a group", []}] = changeset.errors
  end

  test "deleting a role with granted permissions", %{role: role, permission: permission} do
    :ok = Permittable.grant_to(role, permission)
    changeset = Role.changeset(role, %{})
    assert {:error, changeset} = Repo.delete(changeset)
    assert [id: {"cannot delete role that has been granted permissions", []}] = changeset.errors
  end
end

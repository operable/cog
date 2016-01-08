defmodule RoleTest do
  use Cog.ModelCase

  setup do
    {:ok, [role: role("admin"),
           permission: permission("test:do_stuff")]}
  end

  test "permissions may be granted to roles", %{role: role, permission: permission} do
    :ok = Permittable.grant_to(role, permission)
    assert_permission_is_granted(role, permission)
  end

  test "adding a permission to a role is idempotent", %{role: role, permission: permission} do
    Permittable.grant_to(role, permission)
    assert(:ok = Permittable.grant_to(role, permission))
  end

end

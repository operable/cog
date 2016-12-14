defmodule Cog.Test.Commands.Permission.RevokeTest do
  use Cog.CommandCase, command_module: Cog.Commands.Permission

  alias Cog.Commands.Permission.Revoke

  import Cog.Support.ModelUtilities, only: [permission: 1,
                                            with_permission: 2,
                                            role: 1]

  import DatabaseAssertions, only: [assert_permission_is_granted: 2,
                                    refute_permission_is_granted: 2]

  test "revoking a permission  works" do
    permission = permission("site:foo")
    role = role("admin") |> with_permission(permission)

    payload = new_req(args: ["site:foo", "admin"])
              |> send_req(Revoke)
              |> unwrap()

    assert %{permission: %{bundle: "site", name: "foo"},
             role: %{name: "admin",
                     permissions: []}} = payload

    refute_permission_is_granted(role, permission)
  end

  test "revoking a permission from multiple roles fails" do
    foo = permission("site:foo")
    roles = for name <- ["sec", "dev", "ops"] do
      role(name) |> with_permission(foo)
    end

    error = new_req(args: ["site:foo", "sec", "dev", "ops"])
            |> send_req(Revoke)
            |> unwrap_error()

    assert(error == "Too many args. Arguments required: exactly 2.")

    for role <- roles do
      assert_permission_is_granted(role, foo)
    end
  end

  test "revoking a permission from a role requires an existing permission" do
    role("admin")

    error = new_req(args: ["site:wat", "admin"])
            |> send_req(Revoke)
            |> unwrap_error()

    assert(error == "Could not find 'permission' with the name 'site:wat'")
  end

  test "revoking a permission from a role requires an existing role" do
    permission("site:foo")

    error = new_req(args: ["site:foo", "wat"])
            |> send_req(Revoke)
            |> unwrap_error()

    assert(error == "Could not find 'role' with the name 'wat'")
  end

  test "revoking a permission from a role requires the role" do
    permission("site:foo")

    error = new_req(args: ["site:foo"])
            |> send_req(Revoke)
            |> unwrap_error()

    assert(error == "Not enough args. Arguments required: exactly 2.")
  end

  test "revoking permissions requires string arguments" do
    error = new_req(args: [123, 456])
            |> send_req(Revoke)
            |> unwrap_error()

    assert(error == "Arguments must be strings")
  end

end

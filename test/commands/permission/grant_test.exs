defmodule Cog.Test.Commands.Permission.GrantTest do
  use Cog.CommandCase, command_module: Cog.Commands.Permission

  alias Cog.Commands.Permission.Grant

  import Cog.Support.ModelUtilities, only: [permission: 1, role: 1]

  import DatabaseAssertions, only: [assert_permission_is_granted: 2,
                                    refute_permission_is_granted: 2]

  test "granting a permission works" do
    role = role("admin")
    permission = permission("site:foo")

    payload = new_req(args: ["site:foo", "admin"])
              |> send_req(Grant)
              |> unwrap()

    assert %{permission: %{bundle: "site", name: "foo"},
             role: %{name: "admin",
                     permissions: [%{bundle: "site",
                                     name: "foo"}]}} = payload

    assert_permission_is_granted(role, permission)
  end

  test "granting a permission to multiple roles fails" do
    dev = role("dev")
    ops = role("ops")

    foo = permission("site:foo")

    error = new_req(args: ["site:foo", "dev", "ops"])
            |> send_req(Grant)
            |> unwrap_error()

    assert(error == "Too many args. Arguments required: exactly 2.")

    for role <- [dev,ops] do
      refute_permission_is_granted(role, foo)
    end
  end

  test "granting a permission to a role requires an existing permission" do
    role("admin")

    error = new_req(args: ["site:wat", "admin"])
            |> send_req(Grant)
            |> unwrap_error()

    assert(error == "Could not find 'permission' with the name 'site:wat'")
  end

  test "granting a permission to a role requires an existing role" do
    permission("site:foo")

    error = new_req(args: ["site:foo", "wat"])
            |> send_req(Grant)
            |> unwrap_error()

    assert(error == "Could not find 'role' with the name 'wat'")
  end

  test "granting a permission to a role requires the role" do
    permission("site:foo")

    error = new_req(args: ["site:foo"])
            |> send_req(Grant)
            |> unwrap_error()

    assert(error == "Not enough args. Arguments required: exactly 2.")
  end

  test "granting permissions requires string arguments" do
    error = new_req(args: [123, 456])
            |> send_req(Grant)
            |> unwrap_error()

    assert(error == "Arguments must be strings")
  end
end

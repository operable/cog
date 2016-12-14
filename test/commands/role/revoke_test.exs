defmodule Cog.Test.Commands.Role.RevokeTest do
  use Cog.CommandCase, command_module: Cog.Commands.Role.Revoke

  import Cog.Support.ModelUtilities,
    only: [role: 1, group: 1, add_to_group: 2]

  import DatabaseAssertions,
    only: [assert_role_is_granted: 2, refute_role_is_granted: 2]

  test "revoking a role works" do
    role = role("aws-admin")
    group = group("ops")
    Permittable.grant_to(group, role)

    payload = new_req(args: ["aws-admin", "ops"])
              |> send_req()
              |> unwrap()

    assert %{role: %{name: "aws-admin"},
             group: %{name: "ops"}} = payload

    refute_role_is_granted(group, role)
  end

  test "revoking a role from multiple groups fails" do
    role = role("aws-admin")
    groups = for name <- ["dev", "ops"] do
      group = group(name)
      Permittable.grant_to(group, role)
      group
    end

    error = new_req(args: ["aws-admin", "dev", "ops"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Too many args. Arguments required: exactly 2.")

    for group <- groups do
      assert_role_is_granted(group, role)
    end
  end

  test "revoking a role from a group requires an existing group" do
    role("aws-admin")
    error = new_req(args: ["aws-admin", "not-real"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Could not find 'group' with the name 'not-real'")
  end

  test "revoking a role from a group requires an existing role" do
    group("ops")
    error = new_req(args: ["not-real", "ops"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Could not find 'role' with the name 'not-real'")
  end

  test "revoking a role from a group requires the group" do
    role("aws-admin")
    error = new_req(args: ["aws-admin"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Not enough args. Arguments required: exactly 2.")
  end

  test "revoking roles requires string arguments" do
    error = new_req(args: [123, 456])
            |> send_req()
            |> unwrap_error()

    assert(error == "Arguments must be strings")
  end

  test "the cog-admin role can be revoked from a group" do
    role = role("cog-admin")
    group = group("ops")
    Permittable.grant_to(group, role)

    payload = new_req(args: ["cog-admin", "ops"])
              |> send_req()
              |> unwrap()

    assert %{role: %{name: "cog-admin"},
             group: %{name: "ops"}} = payload

    refute_role_is_granted(group, role)
  end

  test "the cog-admin role cannot be revoked from the cog-admin group" do
    role = role("cog-admin")
    group = group("cog-admin")
    add_to_group(group, role)

    error = new_req(args: ["cog-admin", "cog-admin"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Cannot revoke role \"cog-admin\" from group \"cog-admin\": grant is permanent")

    assert_role_is_granted(group, role)
  end
end

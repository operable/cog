defmodule Cog.Test.Commands.Role.GrantTest do
  use Cog.CommandCase, command_module: Cog.Commands.Role.Grant

  alias Cog.Repository.Roles
  import Cog.Support.ModelUtilities, only: [role: 1, group: 1]
  import DatabaseAssertions, only: [assert_role_is_granted: 2,
                                    refute_role_is_granted: 2]

  test "granting a role to a group works" do
    role = role("aws-admin")
    group = group("ops")

    payload = new_req(args: ["aws-admin", "ops"])
              |> send_req()
              |> unwrap()

    assert %{role: %{name: "aws-admin"},
             group: %{name: "ops"}} = payload

    assert_role_is_granted(group, role)
  end

  test "granting a role to multiple groups fails" do
    role = role("aws-admin")
    groups = for name <- ["dev", "ops"] do
      group(name)
    end

    error = new_req(args: ["aws-admin", "dev", "ops"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Too many args. Arguments required: exactly 2.")

    for group <- groups do
      refute_role_is_granted(group, role)
    end
  end

  test "granting a role to a group requires an existing role" do
    group("ops")
    error = new_req(args: ["not-real", "ops"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Could not find 'role' with the name 'not-real'")
  end

  test "granting a role to a group requires an existing group" do
    role("aws-admin")
    error = new_req(args: ["aws-admin", "not-real"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Could not find 'group' with the name 'not-real'")
  end

  test "granting a role to a group requires the group" do
    role("aws-admin")
    error = new_req(args: ["aws-admin"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Not enough args. Arguments required: exactly 2.")
  end

  test "granting roles requires string arguments" do
    error = new_req(args: [123, 456])
            |> send_req()
            |> unwrap_error()

    assert(error == "Arguments must be strings")
  end

  test "can grant the cog-admin role to a group" do
    group = group("ops")
    role("cog-admin")

    payload = new_req(args: ["cog-admin", "ops"])
              |> send_req()
              |> unwrap()

    assert %{role: %{name: "cog-admin"},
             group: %{name: "ops"}} = payload

    role = Roles.by_name("cog-admin")
    assert_role_is_granted(group, role)
  end
end

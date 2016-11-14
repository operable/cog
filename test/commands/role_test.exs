defmodule Cog.Test.Commands.RoleTest do
  use Cog.CommandCase, command_module: Cog.Commands.Role

  import Cog.Support.ModelUtilities, only: [role: 1,
                                            group: 1,
                                            add_to_group: 2,
                                            with_permission: 2]

  alias Cog.Repository.Roles
  #alias Cog.Repository.Groups

  #alias Cog.Models.Role

  import DatabaseAssertions, only: [assert_role_is_granted: 2,
                                    refute_role_is_granted: 2]

  test "listing roles works" do
    role("admin")
    role("cog-admin")
    payload = new_req(args: ["list"])
              |> send_req()
              |> unwrap()
              |> Enum.sort_by(&(&1[:name]))

    assert [%{name: "admin"},
            %{name: "cog-admin"}] = payload
  end

  test "listing is the default action" do
    role("admin")
    role("cog-admin")
    payload = new_req()
              |> send_req()
              |> unwrap()
              |> Enum.sort_by(&(&1[:name]))

    assert [%{name: "admin"},
            %{name: "cog-admin"}] = payload
  end

  test "getting information on a role works" do
    role("testing") |> with_permission("site:foo") |> with_permission("site:bar")

    payload = new_req(args: ["info", "testing"])
              |> send_req()
              |> unwrap()

    assert %{id: _,
             name: "testing"} = payload
    assert [%{bundle: "site", name: "bar"},
            %{bundle: "site", name: "foo"}] = Enum.sort_by(payload[:permissions], &(&1[:name]))
  end

  test "getting information for a non-existent role fails" do
    error = new_req(args: ["info", "wat"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Could not find 'role' with the name 'wat'")
  end

  test "getting information requires a role name" do
    error = new_req(args: ["info"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Not enough args. Arguments required: exactly 1.")
  end

  test "you can only get information on one role at a time" do
    role("foo")
    role("bar")
    error = new_req(args: ["info", "foo", "bar"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Too many args. Arguments required: exactly 1.")
  end

  test "information requires a string argument" do
    error = new_req(args: ["info", 123])
            |> send_req()
            |> unwrap_error()

    assert(error == "Arguments must be strings")
  end

  test "creating a role works" do
    payload = new_req(args: ["create", "foo"])
              |> send_req()
              |> unwrap()

    assert %{name: "foo"} = payload
    assert Roles.by_name("foo")
  end

  test "creating a role that already exists fails" do
    role("foo")
    error = new_req(args: ["create", "foo"])
            |> send_req()
            |> unwrap_error()

    assert(error == "name has already been taken")
  end

  test "to create a role, a name must be given" do
    error = new_req(args: ["create"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Not enough args. Arguments required: exactly 1.")
  end

  test "only one role can be created at a time" do
    error = new_req(args: ["create", "foo", "bar", "baz"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Too many args. Arguments required: exactly 1.")

    for name <- ["foo","bar","baz"] do
      refute Roles.by_name(name)
    end
  end

  test "role creation requires a string argument" do
    error = new_req(args: ["create", 123])
            |> send_req()
            |> unwrap_error()

    assert(error == "Arguments must be strings")
  end

  test "deleting a role works" do
    role("foo")
    payload = new_req(args: ["delete", "foo"])
              |> send_req()
              |> unwrap()

    assert %{name: "foo"} = payload
    refute Roles.by_name("foo")
  end

  test "deleting a non-existent role fails" do
    error = new_req(args: ["delete", "not-real"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Could not find 'role' with the name 'not-real'")
  end

  test "only one role can be deleted at a time" do
    roles = ["dev", "ops", "sec"]
    for name <- roles do
      role(name)
    end
    error = new_req(args: ["delete", "dev", "ops", "sec"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Too many args. Arguments required: exactly 1.")

    for name <- roles do
      assert Roles.by_name(name)
    end
  end

  test "to delete a role, a name must be given" do
    error = new_req(args: ["delete"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Not enough args. Arguments required: exactly 1.")
  end

  test "the 'cog-admin' role cannot be deleted" do
    role("cog-admin")
    error = new_req(args: ["delete", "cog-admin"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Cannot alter protected role cog-admin")
  end

  test "role deletion requires a string argument" do
    error = new_req(args: ["delete", 123])
            |> send_req()
            |> unwrap_error()

    assert(error == "Arguments must be strings")
  end

  # This functionality will be implemented with https://github.com/operable/cog/issues/794
  @tag :skip
  test "can't delete a role if any group has it" do
    flunk "implement me"
  end

  test "granting a role to a group works" do
    role = role("aws-admin")
    group = group("ops")

    payload = new_req(args: ["grant", "aws-admin", "ops"])
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

    error = new_req(args: ["grant", "aws-admin", "dev", "ops"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Too many args. Arguments required: exactly 2.")

    for group <- groups do
      refute_role_is_granted(group, role)
    end
  end

  test "granting a role to a group requires an existing role" do
    group("ops")
    error = new_req(args: ["grant", "not-real", "ops"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Could not find 'role' with the name 'not-real'")
  end

  test "granting a role to a group requires an existing group" do
    role("aws-admin")
    error = new_req(args: ["grant", "aws-admin", "not-real"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Could not find 'group' with the name 'not-real'")
  end

  test "granting a role to a group requires the group" do
    role("aws-admin")
    error = new_req(args: ["grant", "aws-admin"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Not enough args. Arguments required: exactly 2.")
  end

  test "granting roles requires string arguments" do
    error = new_req(args: ["grant", 123, 456])
            |> send_req()
            |> unwrap_error()

    assert(error == "Arguments must be strings")
  end

  test "can grant the cog-admin role to a group" do
    group = group("ops")
    role("cog-admin")

    payload = new_req(args: ["grant", "cog-admin", "ops"])
              |> send_req()
              |> unwrap()

    assert %{role: %{name: "cog-admin"},
             group: %{name: "ops"}} = payload

    role = Roles.by_name("cog-admin")
    assert_role_is_granted(group, role)
  end

  test "revoking a role works" do
    role = role("aws-admin")
    group = group("ops")
    Permittable.grant_to(group, role)

    payload = new_req(args: ["revoke", "aws-admin", "ops"])
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

    error = new_req(args: ["revoke", "aws-admin", "dev", "ops"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Too many args. Arguments required: exactly 2.")

    for group <- groups do
      assert_role_is_granted(group, role)
    end
  end

  test "revoking a role from a group requires an existing group" do
    role("aws-admin")
    error = new_req(args: ["revoke", "aws-admin", "not-real"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Could not find 'group' with the name 'not-real'")
  end

  test "revoking a role from a group requires an existing role" do
    group("ops")
    error = new_req(args: ["revoke", "not-real", "ops"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Could not find 'role' with the name 'not-real'")
  end

  test "revoking a role from a group requires the group" do
    role("aws-admin")
    error = new_req(args: ["revoke", "aws-admin"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Not enough args. Arguments required: exactly 2.")
  end

  test "revoking roles requires string arguments" do
    error = new_req(args: ["revoke", 123, 456])
            |> send_req()
            |> unwrap_error()

    assert(error == "Arguments must be strings")
  end

  test "the cog-admin role can be revoked from a group" do
    role = role("cog-admin")
    group = group("ops")
    Permittable.grant_to(group, role)

    payload = new_req(args: ["revoke", "cog-admin", "ops"])
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

    error = new_req(args: ["revoke", "cog-admin", "cog-admin"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Cannot revoke role \"cog-admin\" from group \"cog-admin\": grant is permanent")

    assert_role_is_granted(group, role)
  end

  test "providing an unrecognized subcommand fails" do
    error = new_req(args: ["do-something"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Unknown subcommand 'do-something'")
  end

  test "renaming a role works" do
    %{id: id} = role("foo")

    payload = new_req(args: ["rename", "foo", "bar"])
              |> send_req()
              |> unwrap()

    assert %{id: ^id,
             name: "bar",
             old_name: "foo"} = payload

    refute Roles.by_name("foo")
    assert %{id: ^id} = Roles.by_name("bar")
  end

  test "the cog-admin role cannot be renamed" do
    role("cog-admin")
    error = new_req(args: ["rename", "cog-admin", "monkeys"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Cannot alter protected role cog-admin")
  end

  test "renaming a non-existent role fails" do
    error = new_req(args: ["rename", "not-here", "monkeys"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Could not find 'role' with the name 'not-here'")
  end

  test "renaming to an already-existing role fails" do
    role("foo")
    role("bar")

    error = new_req(args: ["rename", "foo", "bar"])
            |> send_req()
            |> unwrap_error()

    assert(error == "name has already been taken")
  end

  test "renaming requires a new name" do
    error = new_req(args: ["rename", "foo"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Not enough args. Arguments required: exactly 2.")
  end

  test "rename requires a role and a name" do
    error = new_req(args: ["rename"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Not enough args. Arguments required: exactly 2.")
  end

  test "renaming requires string arguments" do
    error = new_req(args: ["rename", 123, 456])
            |> send_req()
            |> unwrap_error()

    assert(error == "Arguments must be strings")
  end

  test "passing an unknown subcommand fails" do
    error = new_req(args: ["not-a-subcommand"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Unknown subcommand 'not-a-subcommand'")
  end

end

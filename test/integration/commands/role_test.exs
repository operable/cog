defmodule Integration.Commands.RoleTest do
  use Cog.AdapterCase, adapter: "test"

  alias Cog.Repository.Roles
  alias Cog.Repository.Groups

  alias Cog.Models.Role

  import DatabaseAssertions, only: [assert_role_is_granted: 2,
                                    refute_role_is_granted: 2]

  setup do
    user = user("belf", first_name: "Buddy", last_name: "Elf")
    |> with_chat_handle_for("test")
    |> with_permission("operable:manage_groups")
    |> with_permission("operable:manage_roles")

    {:ok, %{user: user}}
  end

  test "listing roles works", %{user: user} do
    role("admin")
    payload = send_message(user, "@bot: operable:role list")
    |> Enum.sort_by(&(&1[:name]))

    assert [%{name: "admin"},
            %{name: "cog-admin"}] = payload
  end

  test "listing is the default action", %{user: user} do
    role("admin")
    payload = send_message(user, "@bot: operable:role")
    |> Enum.sort_by(&(&1[:name]))

    assert [%{name: "admin"},
            %{name: "cog-admin"}] = payload
  end

  test "getting information on a role works", %{user: user} do
    role("testing") |> with_permission("site:foo") |> with_permission("site:bar")

    [payload] = send_message(user, "@bot: operable:role info testing")

    assert %{id: _,
             name: "testing"} = payload
    assert [%{bundle: "site", name: "bar"},
            %{bundle: "site", name: "foo"}] = Enum.sort_by(payload[:permissions], &(&1[:name]))
  end

  test "getting information for a non-existent role fails", %{user: user} do
    response = send_message(user, "@bot: operable:role info wat")
    assert_error_message_contains(response, "Could not find 'role' with the name 'wat'")
  end

  test "getting information requires a role name", %{user: user} do
    response = send_message(user, "@bot: operable:role info")
    assert_error_message_contains(response, "Not enough args. Arguments required: exactly 1.")
  end

  test "you can only get information on one role at a time", %{user: user} do
    role("foo")
    role("bar")
    response = send_message(user, "@bot: operable:role info foo bar")
    assert_error_message_contains(response, "Too many args. Arguments required: exactly 1.")
  end

  test "information requires a string argument", %{user: user} do
    response = send_message(user, "@bot: operable:role info 123")
    assert_error_message_contains(response, "Arguments must be strings")
  end

  test "creating a role works", %{user: user} do
    payload = send_message(user, "@bot: operable:role create foo")
    assert [%{name: "foo"}] = payload
    assert Roles.by_name("foo")
  end

  test "creating a role that already exists fails", %{user: user} do
    role("foo")
    response = send_message(user, "@bot: operable:role create foo")
    assert_error_message_contains(response, "name has already been taken")
  end

  test "to create a role, a name must be given", %{user: user} do
    response = send_message(user, "@bot: operable:role create")
    assert_error_message_contains(response, "Not enough args. Arguments required: exactly 1.")
  end

  test "only one role can be created at a time", %{user: user} do
    response = send_message(user, "@bot: operable:role create foo bar baz")
    assert_error_message_contains(response, "Too many args. Arguments required: exactly 1.")

    for name <- ["foo","bar","baz"] do
      refute Roles.by_name(name)
    end
  end

  test "role creation requires a string argument", %{user: user} do
    response = send_message(user, "@bot: operable:role create 123")
    assert_error_message_contains(response, "Arguments must be strings")
  end

  test "deleting a role works", %{user: user} do
    role("foo")
    payload = send_message(user, "@bot: operable:role delete foo")
    assert [%{name: "foo"}] = payload
    refute Roles.by_name("foo")
  end

  test "deleting a non-existent role fails", %{user: user} do
    response = send_message(user, "@bot: operable:role delete not-real")
    assert_error_message_contains(response, "Could not find 'role' with the name 'not-real'")
  end

  test "only one role can be deleted at a time", %{user: user} do
    roles = ["dev", "ops", "sec"]
    for name <- roles do
      role(name)
    end
    response = send_message(user, "@bot: operable:role delete dev ops sec")
    assert_error_message_contains(response, "Too many args. Arguments required: exactly 1.")

    for name <- roles do
      assert Roles.by_name(name)
    end
  end

  test "to delete a role, a name must be given", %{user: user} do
    response = send_message(user, "@bot: operable:role delete")
    assert_error_message_contains(response, "Arguments required: exactly 1.")
  end

  test "the 'cog-admin' role cannot be deleted", %{user: user} do
    response = send_message(user, "@bot: operable:role delete cog-admin")
    assert_error_message_contains(response, "Cannot alter protected role cog-admin")
  end

  test "role deletion requires a string argument", %{user: user} do
    response = send_message(user, "@bot: operable:role delete 123")
    assert_error_message_contains(response, "Arguments must be strings")
  end

  # This functionality will be implemented with https://github.com/operable/cog/issues/794
  @tag :skip
  test "can't delete a role if any group has it" do
    flunk "implement me"
  end

  test "granting a role to a group works", %{user: user} do
    role = role("aws-admin")
    group = group("ops")

    [payload] = send_message(user, "@bot: operable:role grant aws-admin ops")
    assert %{role: %{name: "aws-admin"},
             group: %{name: "ops"}} = payload

    assert_role_is_granted(group, role)
  end

  test "granting a role to multiple groups fails", %{user: user} do
    role = role("aws-admin")
    groups = for name <- ["dev", "ops"] do
      group(name)
    end

    response = send_message(user, "@bot: operable:role grant aws-admin dev ops")
    assert_error_message_contains(response, "Too many args. Arguments required: exactly 2.")

    for group <- groups do
      refute_role_is_granted(group, role)
    end
  end

  test "granting a role to a group requires an existing role", %{user: user} do
    group("ops")
    response = send_message(user, "@bot: operable:role grant not-real ops")
    assert_error_message_contains(response, "Could not find 'role' with the name 'not-real'")
  end

  test "granting a role to a group requires an existing group", %{user: user} do
    role("aws-admin")
    response = send_message(user, "@bot: operable:role grant aws-admin not-real")
    assert_error_message_contains(response, "Could not find 'group' with the name 'not-real'")
  end

  test "granting a role to a group requires the group", %{user: user} do
    role("aws-admin")
    response = send_message(user, "@bot: operable:role grant aws-admin")
    assert_error_message_contains(response, "Arguments required: exactly 2.")
  end

  test "granting roles requires string arguments", %{user: user} do
    response = send_message(user, "@bot: operable:role grant 123 456")
    assert_error_message_contains(response, "Arguments must be strings")
  end

  test "can grant the cog-admin role to a group", %{user: user} do
    group = group("ops")

    [payload] = send_message(user, "@bot: operable:role grant cog-admin ops")
    assert %{role: %{name: "cog-admin"},
             group: %{name: "ops"}} = payload

    role = Roles.by_name("cog-admin")
    assert_role_is_granted(group, role)
  end

  test "revoking a role works", %{user: user} do
    role = role("aws-admin")
    group = group("ops")
    Permittable.grant_to(group, role)

    [payload] = send_message(user, "@bot: operable:role revoke aws-admin ops")
    assert %{role: %{name: "aws-admin"},
             group: %{name: "ops"}} = payload

    refute_role_is_granted(group, role)
  end

  test "revoking a role from multiple groups fails", %{user: user} do
    role = role("aws-admin")
    groups = for name <- ["dev", "ops"] do
      group = group(name)
      Permittable.grant_to(group, role)
      group
    end

    response = send_message(user, "@bot: operable:role revoke aws-admin dev ops")
    assert_error_message_contains(response, "Too many args. Arguments required: exactly 2.")

    for group <- groups do
      assert_role_is_granted(group, role)
    end
  end

  test "revoking a role from a group requires an existing group", %{user: user} do
    role("aws-admin")
    response = send_message(user, "@bot: operable:role revoke aws-admin not-real")
    assert_error_message_contains(response, "Could not find 'group' with the name 'not-real'")
  end

  test "revoking a role from a group requires an existing role", %{user: user} do
    group("ops")
    response = send_message(user, "@bot: operable:role revoke not-real ops")
    assert_error_message_contains(response, "Could not find 'role' with the name 'not-real'")
  end

  test "revoking a role from a group requires the group", %{user: user} do
    role("aws-admin")
    response = send_message(user, "@bot: operable:role revoke aws-admin")
    assert_error_message_contains(response, "Not enough args. Arguments required: exactly 2.")
  end

  test "revoking roles requires string arguments", %{user: user} do
    response = send_message(user, "@bot: operable:role revoke 123 456")
    assert_error_message_contains(response, "Arguments must be strings")
  end

  test "the cog-admin role can be revoked from a group", %{user: user} do
    role = Roles.by_name("cog-admin")
    group = group("ops")
    Permittable.grant_to(group, role)

    [payload] = send_message(user, "@bot: operable:role revoke cog-admin ops")
    assert %{role: %{name: "cog-admin"},
             group: %{name: "ops"}} = payload

    refute_role_is_granted(group, role)
  end

  test "the cog-admin role cannot be revoked from the cog-admin group", %{user: user} do
    role = Roles.by_name("cog-admin")
    {:ok, group} = Groups.by_name("cog-admin")

    response = send_message(user, "@bot: operable:role revoke cog-admin cog-admin")
    assert_error_message_contains(response , "Cannot revoke role \"cog-admin\" from group \"cog-admin\": grant is permanent")

    assert_role_is_granted(group, role)
  end

  test "providing an unrecognized subcommand fails", %{user: user} do
    response = send_message(user, "@bot: operable:role do-something")
    assert_error_message_contains(response , "Unknown subcommand 'do-something'")
  end

  test "renaming a role works", %{user: user} do
    %Role{id: id} = role("foo")

    [payload] = send_message(user, "@bot: operable:role rename foo bar")
    assert %{id: ^id,
             name: "bar",
             old_name: "foo"} = payload

    refute Roles.by_name("foo")
    assert %Role{id: ^id} = Roles.by_name("bar")
  end

  test "the cog-admin role cannot be renamed", %{user: user} do
    response = send_message(user, "@bot: operable:role rename cog-admin monkeys")
    assert_error_message_contains(response , "Cannot alter protected role cog-admin")
  end

  test "renaming a non-existent role fails", %{user: user} do
    response = send_message(user, "@bot: operable:role rename not-here monkeys")
    assert_error_message_contains(response , "Could not find 'role' with the name 'not-here'")
  end

  test "renaming to an already-existing role fails", %{user: user} do
    role("foo")
    role("bar")

    response = send_message(user, "@bot: operable:role rename foo bar")
    assert_error_message_contains(response , "name has already been taken")
  end

  test "renaming requires a new name", %{user: user} do
    response = send_message(user, "@bot: operable:role rename foo")
    assert_error_message_contains(response , "Not enough args. Arguments required: exactly 2")
  end

  test "rename requires a role and a name", %{user: user} do
    response = send_message(user, "@bot: operable:role rename")
    assert_error_message_contains(response , "Not enough args. Arguments required: exactly 2")
  end

  test "renaming requires string arguments", %{user: user} do
    response = send_message(user, "@bot: operable:role rename 123 456")
    assert_error_message_contains(response , "Arguments must be strings")
  end

  test "passing an unknown subcommand fails", %{user: user} do
    response = send_message(user, "@bot: operable:role not-a-subcommand")
    assert_error_message_contains(response, "Whoops! An error occurred. Unknown subcommand 'not-a-subcommand'")
  end

end

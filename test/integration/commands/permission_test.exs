defmodule Integration.Commands.PermissionTest do
  use Cog.AdapterCase, adapter: "test"

  alias Cog.Repository.Permissions

  import DatabaseAssertions, only: [assert_permission_is_granted: 2,
                                    refute_permission_is_granted: 2]

  setup do
    user = user("vanstee", first_name: "Patrick", last_name: "Van Stee")
    |> with_chat_handle_for("test")
    |> with_permission("operable:manage_roles")
    |> with_permission("operable:manage_permissions")

    {:ok, %{user: user}}
  end

  test "listing permissions works", %{user: user} do
    payload = send_message(user, "@bot: operable:permission list")
    |> Enum.sort_by(fn(p) -> "#{p[:bundle]}:#{p[:name]}" end)

    assert [%{bundle: "operable", name: "manage_commands"},
            %{bundle: "operable", name: "manage_groups"},
            %{bundle: "operable", name: "manage_permissions"},
            %{bundle: "operable", name: "manage_relays"},
            %{bundle: "operable", name: "manage_roles"},
            %{bundle: "operable", name: "manage_triggers"},
            %{bundle: "operable", name: "manage_users"},
            %{bundle: "operable", name: "st-echo"},
            %{bundle: "operable", name: "st-thorn"}] = payload
  end

  test "listing is the default action", %{user: user} do
    payload = send_message(user, "@bot: operable:permission")
    |> Enum.sort_by(fn(p) -> "#{p[:bundle]}:#{p[:name]}" end)

    assert [%{bundle: "operable", name: "manage_commands"},
            %{bundle: "operable", name: "manage_groups"},
            %{bundle: "operable", name: "manage_permissions"},
            %{bundle: "operable", name: "manage_relays"},
            %{bundle: "operable", name: "manage_roles"},
            %{bundle: "operable", name: "manage_triggers"},
            %{bundle: "operable", name: "manage_users"},
            %{bundle: "operable", name: "st-echo"},
            %{bundle: "operable", name: "st-thorn"}] = payload
  end

  test "getting information on a permission works", %{user: user} do
    permission("site:foo")
    [payload] = send_message(user, "@bot: operable:permission info site:foo")
    assert %{id: _,
             bundle: "site",
             name: "foo"} = payload
  end

  test "getting information for a non-existent permission fails", %{user: user} do
    response = send_message(user, "@bot: operable:permission info site:wat")
    assert_error_message_contains(response, "Could not find 'permission' with the name 'site:wat'")
  end

  test "getting information requires a permission name", %{user: user} do
    response = send_message(user, "@bot: operable:permission info")
    assert_error_message_contains(response, "Not enough args. Arguments required: exactly 1.")
  end

  test "you can only get information on one permission at a time", %{user: user} do
    permission("site:foo")
    permission("site:bar")
    response = send_message(user, "@bot: operable:permission info site:foo site:bar")
    assert_error_message_contains(response, "Too many args. Arguments required: exactly 1.")
  end

  test "information requires a string argument", %{user: user} do
    response = send_message(user, "@bot: operable:permission info 123")
    assert_error_message_contains(response, "Arguments must be strings")
  end

  test "creating a permission works", %{user: user} do
    payload = send_message(user, "@bot: operable:permission create site:foo")
    assert [%{bundle: "site", name: "foo"}] = payload
    assert Permissions.by_name("site:foo")
  end

  test "creating a non-site permission fails", %{user: user} do
    response = send_message(user, "@bot: operable:permission create operable:naughty")
    assert_error_message_contains(response,
                                  "Only permissions in the `site` namespace can be created or deleted; please specify permission as `site:<NAME>`")
    refute Permissions.by_name("operable:naughty")
  end

  test "giving a bare name without a bundle name fails", %{user: user} do
    response = send_message(user, "@bot: operable:permission create wat")
    assert_error_message_contains(response,
                                  "Only permissions in the `site` namespace can be created or deleted; please specify permission as `site:<NAME>`")
  end

  test "creating a permission that already exists fails", %{user: user} do
    permission("site:foo")
    response = send_message(user, "@bot: operable:permission create site:foo")
    assert_error_message_contains(response, "name has already been taken")
  end

  test "to create a permission a name must be given", %{user: user} do
    response = send_message(user, "@bot: operable:permission create")
    assert_error_message_contains(response, "Not enough args. Arguments required: exactly 1")
  end

  test "only one permission can be created at a time", %{user: user} do
    response = send_message(user, "@bot: operable:permission create site:foo site:bar")
    assert_error_message_contains(response, "Too many args. Arguments required: exactly 1")
    refute Permissions.by_name("site:foo")
    refute Permissions.by_name("site:bar")
  end

  test "deleting a permission works", %{user: user} do
    permission("site:foo")

    payload = send_message(user, "@bot: operable:permission delete site:foo")
    assert [%{bundle: "site", name: "foo"}] = payload

    refute Permissions.by_name("site:foo")
  end

  test "deleting a non-existent permission fails", %{user: user} do
    response = send_message(user, "@bot: operable:permission delete site:wat")
    assert_error_message_contains(response, "Could not find 'permission' with the name 'site:wat'")
  end

  test "only one permission can be deleted at a time", %{user: user} do
    permission("site:foo")
    permission("site:bar")
    response = send_message(user, "@bot: operable:permission delete site:foo site bar")
    assert_error_message_contains(response, "Too many args. Arguments required: exactly 1")
    assert Permissions.by_name("site:foo")
    assert Permissions.by_name("site:bar")
  end

  test "to delete a permission a name must be given", %{user: user} do
    response = send_message(user, "@bot: operable:permission delete")
    assert_error_message_contains(response, "Not enough args. Arguments required: exactly 1")
  end

  test "only site permissions may be deleted", %{user: user} do
    response = send_message(user, "@bot: operable:permission delete operable:manage_permissions")
    assert_error_message_contains(response , "Only permissions in the `site` namespace can be created or deleted; please specify permission as `site:<NAME>`")
    assert Permissions.by_name("operable:manage_permissions")
  end

  test "granting a permission works", %{user: user} do
    role = role("admin")
    permission = permission("site:foo")

    [payload] = send_message(user, "@bot: operable:permission grant site:foo admin")
    assert %{permission: %{bundle: "site", name: "foo"},
             role: %{name: "admin",
                     permissions: [%{bundle: "site",
                                     name: "foo"}]}} = payload

    assert_permission_is_granted(role, permission)
  end

  test "granting a permission to multiple roles fails", %{user: user} do
    dev = role("dev")
    ops = role("ops")

    foo = permission("site:foo")

    response = send_message(user, "@bot: operable:permission grant site:foo dev ops")
    assert_error_message_contains(response , "Too many args. Arguments required: exactly 2")

    for role <- [dev,ops] do
      refute_permission_is_granted(role, foo)
    end
  end

  test "granting a permission to a role requires an existing permission", %{user: user} do
    role("admin")
    response = send_message(user, "@bot: operable:permission grant site:wat admin")
    assert_error_message_contains(response, "Could not find 'permission' with the name 'site:wat'")
  end

  test "granting a permission to a role requires an existing role", %{user: user} do
    permission("site:foo")
    response = send_message(user, "@bot: operable:permission grant site:foo wat")
    assert_error_message_contains(response, "Could not find 'role' with the name 'wat'")
  end

  test "granting a permission to a role requires the role", %{user: user} do
    permission("site:foo")
    response = send_message(user, "@bot: operable:permission grant site:foo")
    assert_error_message_contains(response, "Not enough args. Arguments required: exactly 2")
  end

  test "granting permissions requires string arguments", %{user: user} do
    response = send_message(user, "@bot: operable:permission grant 123 456")
    assert_error_message_contains(response, "Arguments must be strings")
  end

  test "revoking a permission  works", %{user: user} do
    permission = permission("site:foo")
    role = role("admin") |> with_permission(permission)

    [payload] = send_message(user, "@bot: operable:permission revoke site:foo admin")
    assert %{permission: %{bundle: "site", name: "foo"},
             role: %{name: "admin",
                     permissions: []}} = payload

    refute_permission_is_granted(role, permission)
  end

  test "revoking a permission from multiple roles fails", %{user: user} do
    foo = permission("site:foo")
    roles = for name <- ["sec", "dev", "ops"] do
      role(name) |> with_permission(foo)
    end

    response = send_message(user, "@bot: operable:permission revoke site:foo sec dev ops")
    assert_error_message_contains(response, "Too many args. Arguments required: exactly 2")

    for role <- roles do
      assert_permission_is_granted(role, foo)
    end
  end

  test "revoking a permission from a role requires an existing permission", %{user: user} do
    role("admin")
    response = send_message(user, "@bot: operable:permission revoke site:wat admin")
    assert_error_message_contains(response, "Could not find 'permission' with the name 'site:wat'")
  end

  test "revoking a permission from a role requires an existing role", %{user: user} do
    permission("site:foo")
    response = send_message(user, "@bot: operable:permission revoke site:foo wat")
    assert_error_message_contains(response, "Could not find 'role' with the name 'wat'")
  end

  test "revoking a permission from a role requires the role", %{user: user} do
    permission("site:foo")
    response = send_message(user, "@bot: operable:permission revoke site:foo")
    assert_error_message_contains(response, "Not enough args. Arguments required: exactly 2")
  end

  test "revoking permissions requires string arguments", %{user: user} do
    response = send_message(user, "@bot: operable:permission revoke 123 456")
    assert_error_message_contains(response, "Arguments must be strings")
  end

  test "providing an unrecognized subcommand fails", %{user: user} do
    response = send_message(user, "@bot: operable:permission do-something")
    assert_error_message_contains(response , "Unknown subcommand 'do-something'")
  end

end

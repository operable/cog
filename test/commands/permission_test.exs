defmodule Cog.Test.Commands.PermissionTest do
  use Cog.CommandCase, command_module: Cog.Commands.Permission

  alias Cog.Commands.Permission.{List, Create, Delete, Info, Grant}
  alias Cog.Repository.Permissions

  import Cog.Support.ModelUtilities, only: [permission: 1,
                                            with_permission: 2,
                                            role: 1]

  import DatabaseAssertions, only: [assert_permission_is_granted: 2,
                                    refute_permission_is_granted: 2]

  test "listing permissions works" do
    payload = new_req(args: [])
              |> send_req(List)
              |> unwrap()
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

  @tag :skip
  test "listing is the default action" do
    payload = new_req()
              |> send_req()
              |> unwrap()
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

  test "getting information on a permission works" do
    permission("site:foo")

    payload = new_req(args: ["site:foo"])
              |> send_req(Info)
              |> unwrap()

    assert %{id: _,
             bundle: "site",
             name: "foo"} = payload
  end

  test "getting information for a non-existent permission fails" do
    error = new_req(args: ["site:wat"])
            |> send_req(Info)
            |> unwrap_error()

    assert(error == "Could not find 'permission' with the name 'site:wat'")
  end

  test "getting information requires a permission name" do
    error = new_req(args: [])
            |> send_req(Info)
            |> unwrap_error()

    assert(error == "Not enough args. Arguments required: exactly 1.")
  end

  test "you can only get information on one permission at a time" do
    permission("site:foo")
    permission("site:bar")

    error = new_req(args: ["site:foo", "site:bar"])
            |> send_req(Info)
            |> unwrap_error()

    assert(error == "Too many args. Arguments required: exactly 1.")
  end

  test "information requires a string argument" do
    error = new_req(args: [123])
            |> send_req(Info)
            |> unwrap_error()

    assert(error == "Arguments must be strings")
  end

  test "creating a permission works" do
    payload = new_req(args: ["site:foo"])
              |> send_req(Create)
              |> unwrap()

    assert %{bundle: "site", name: "foo"} = payload
    assert Permissions.by_name("site:foo")
  end

  test "creating a non-site permission fails" do
    error = new_req(args: ["operavle:naughty"])
            |> send_req(Create)
            |> unwrap_error()

    message = """
    Only permissions in the `site` namespace can be \
    created or deleted; please specify permission as `site:<NAME>`\
    """
    assert(error == message)
    refute Permissions.by_name("operable:naughty")
  end

  test "giving a bare name without a bundle name fails" do
    error = new_req(args: ["wat"])
            |> send_req(Create)
            |> unwrap_error()

    message = """
    Only permissions in the `site` namespace can be \
    created or deleted; please specify permission as `site:<NAME>`\
    """

    assert(error == message)
  end

  test "creating a permission that already exists fails" do
    permission("site:foo")

    error = new_req(args: ["site:foo"])
            |> send_req(Create)
            |> unwrap_error()

    assert(error == "name has already been taken")
  end

  test "to create a permission a name must be given" do
    error = new_req(args: [])
            |> send_req(Create)
            |> unwrap_error()

    assert(error == "Not enough args. Arguments required: exactly 1.")
  end

  test "only one permission can be created at a time" do
    error = new_req(args: ["site:foo", "site:bar"])
            |> send_req(Create)
            |> unwrap_error()

    assert(error == "Too many args. Arguments required: exactly 1.")
    refute Permissions.by_name("site:foo")
    refute Permissions.by_name("site:bar")
  end

  test "deleting a permission works" do
    permission("site:foo")

    payload = new_req(args: ["site:foo"])
              |> send_req(Delete)
              |> unwrap()

    assert %{bundle: "site", name: "foo"} = payload

    refute Permissions.by_name("site:foo")
  end

  test "deleting a non-existent permission fails" do
    error = new_req(args: ["site:wat"])
            |> send_req(Delete)
            |> unwrap_error()

    assert(error == "Could not find 'permission' with the name 'site:wat'")
  end

  test "only one permission can be deleted at a time" do
    permission("site:foo")
    permission("site:bar")

    error = new_req(args: ["site:foo", "site", "bar"])
            |> send_req(Delete)
            |> unwrap_error()

    assert(error == "Too many args. Arguments required: exactly 1.")
    assert Permissions.by_name("site:foo")
    assert Permissions.by_name("site:bar")
  end

  test "to delete a permission a name must be given" do
    error = new_req(args: [])
            |> send_req(Delete)
            |> unwrap_error()

    assert(error == "Not enough args. Arguments required: exactly 1.")
  end

  test "only site permissions may be deleted" do
    error = new_req(args: ["operable:manage_permissions"])
            |> send_req(Delete)
            |> unwrap_error()

    message = """
    Only permissions in the `site` namespace can be created or deleted; \
    please specify permission as `site:<NAME>`\
    """

    assert(error == message)
    assert Permissions.by_name("operable:manage_permissions")
  end

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

  test "revoking a permission  works" do
    permission = permission("site:foo")
    role = role("admin") |> with_permission(permission)

    payload = new_req(args: ["revoke", "site:foo", "admin"])
              |> send_req()
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

    error = new_req(args: ["revoke", "site:foo", "sec", "dev", "ops"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Too many args. Arguments required: exactly 2.")

    for role <- roles do
      assert_permission_is_granted(role, foo)
    end
  end

  test "revoking a permission from a role requires an existing permission" do
    role("admin")

    error = new_req(args: ["revoke", "site:wat", "admin"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Could not find 'permission' with the name 'site:wat'")
  end

  test "revoking a permission from a role requires an existing role" do
    permission("site:foo")

    error = new_req(args: ["revoke", "site:foo", "wat"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Could not find 'role' with the name 'wat'")
  end

  test "revoking a permission from a role requires the role" do
    permission("site:foo")

    error = new_req(args: ["revoke", "site:foo"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Not enough args. Arguments required: exactly 2.")
  end

  test "revoking permissions requires string arguments" do
    error = new_req(args: ["revoke", 123, 456])
            |> send_req()
            |> unwrap_error()

    assert(error == "Arguments must be strings")
  end

  test "providing an unrecognized subcommand fails" do
    error = new_req(args: ["do-something"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Unknown subcommand 'do-something'")
  end

end

defmodule Cog.Test.Commands.Permission.DeleteTest do
  use Cog.CommandCase, command_module: Cog.Commands.Permission

  import Cog.Support.ModelUtilities, only: [permission: 1]
  alias Cog.Commands.Permission.Delete
  alias Cog.Repository.Permissions

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
end

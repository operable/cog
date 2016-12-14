defmodule Cog.Test.Commands.Permission.CreateTest do
  use Cog.CommandCase, command_module: Cog.Commands.Permission

  import Cog.Support.ModelUtilities, only: [permission: 1]
  alias Cog.Commands.Permission.Create
  alias Cog.Repository.Permissions

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
end

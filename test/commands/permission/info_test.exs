defmodule Cog.Test.Commands.Permission.InfoTest do
  use Cog.CommandCase, command_module: Cog.Commands.Permission

  alias Cog.Commands.Permission.Info
  import Cog.Support.ModelUtilities, only: [permission: 1]

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
end

defmodule Cog.Test.Commands.Role.CreateTest do
  use Cog.CommandCase, command_module: Cog.Commands.Role.Create

  import Cog.Support.ModelUtilities, only: [role: 1]
  alias Cog.Repository.Roles

  test "creating a role works" do
    payload = new_req(args: ["foo"])
              |> send_req()
              |> unwrap()

    assert %{name: "foo"} = payload
    assert Roles.by_name("foo")
  end

  test "creating a role that already exists fails" do
    role("foo")
    error = new_req(args: ["foo"])
            |> send_req()
            |> unwrap_error()

    assert(error == "name has already been taken")
  end

  test "to create a role, a name must be given" do
    error = new_req(args: [])
            |> send_req()
            |> unwrap_error()

    assert(error == "Not enough args. Arguments required: exactly 1.")
  end

  test "only one role can be created at a time" do
    error = new_req(args: ["foo", "bar", "baz"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Too many args. Arguments required: exactly 1.")

    for name <- ["foo","bar","baz"] do
      refute Roles.by_name(name)
    end
  end

  test "role creation requires a string argument" do
    error = new_req(args: [123])
            |> send_req()
            |> unwrap_error()

    assert(error == "Arguments must be strings")
  end
end

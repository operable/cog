defmodule Cog.Test.Commands.RoleTest do
  use Cog.CommandCase, command_module: Cog.Commands.Role.Rename

  import Cog.Support.ModelUtilities, only: [role: 1]
  alias Cog.Repository.Roles

  test "renaming a role works" do
    %{id: id} = role("foo")

    payload = new_req(args: ["foo", "bar"])
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
    error = new_req(args: ["cog-admin", "monkeys"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Cannot alter protected role cog-admin")
  end

  test "renaming a non-existent role fails" do
    error = new_req(args: ["not-here", "monkeys"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Could not find 'role' with the name 'not-here'")
  end

  test "renaming to an already-existing role fails" do
    role("foo")
    role("bar")

    error = new_req(args: ["foo", "bar"])
            |> send_req()
            |> unwrap_error()

    assert(error == "name has already been taken")
  end

  test "renaming requires a new name" do
    error = new_req(args: ["foo"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Not enough args. Arguments required: exactly 2.")
  end

  test "rename requires a role and a name" do
    error = new_req(args: [])
            |> send_req()
            |> unwrap_error()

    assert(error == "Not enough args. Arguments required: exactly 2.")
  end

  test "renaming requires string arguments" do
    error = new_req(args: [123, 456])
            |> send_req()
            |> unwrap_error()

    assert(error == "Arguments must be strings")
  end
end

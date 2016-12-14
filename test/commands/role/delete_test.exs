defmodule Cog.Test.Commands.Role.DeleteTest do
  use Cog.CommandCase, command_module: Cog.Commands.Role.Delete

  import Cog.Support.ModelUtilities, only: [role: 1]
  alias Cog.Repository.Roles

  test "deleting a role works" do
    role("foo")
    payload = new_req(args: ["foo"])
              |> send_req()
              |> unwrap()

    assert %{name: "foo"} = payload
    refute Roles.by_name("foo")
  end

  test "deleting a non-existent role fails" do
    error = new_req(args: ["not-real"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Could not find 'role' with the name 'not-real'")
  end

  test "only one role can be deleted at a time" do
    roles = ["dev", "ops", "sec"]
    for name <- roles do
      role(name)
    end
    error = new_req(args: ["dev", "ops", "sec"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Too many args. Arguments required: exactly 1.")

    for name <- roles do
      assert Roles.by_name(name)
    end
  end

  test "to delete a role, a name must be given" do
    error = new_req(args: [])
            |> send_req()
            |> unwrap_error()

    assert(error == "Not enough args. Arguments required: exactly 1.")
  end

  test "the 'cog-admin' role cannot be deleted" do
    role("cog-admin")
    error = new_req(args: ["cog-admin"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Cannot alter protected role cog-admin")
  end

  test "role deletion requires a string argument" do
    error = new_req(args: [123])
            |> send_req()
            |> unwrap_error()

    assert(error == "Arguments must be strings")
  end

  # This functionality will be implemented with https://github.com/operable/cog/issues/794
  @tag :skip
  test "can't delete a role if any group has it" do
    flunk "implement me"
  end
end

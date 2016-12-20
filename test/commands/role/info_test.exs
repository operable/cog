defmodule Cog.Test.Commands.Role.InfoTest do
  use Cog.CommandCase, command_module: Cog.Commands.Role.Info

  import Cog.Support.ModelUtilities, only: [role: 1, with_permission: 2]

  test "getting information on a role works" do
    role("testing") |> with_permission("site:foo") |> with_permission("site:bar")

    payload = new_req(args: ["testing"])
              |> send_req()
              |> unwrap()

    assert %{id: _,
             name: "testing"} = payload
    assert [%{bundle: "site", name: "bar"},
            %{bundle: "site", name: "foo"}] = Enum.sort_by(payload[:permissions], &(&1[:name]))
  end

  test "getting information for a non-existent role fails" do
    error = new_req(args: ["wat"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Could not find 'role' with the name 'wat'")
  end

  test "getting information requires a role name" do
    error = new_req(args: [])
            |> send_req()
            |> unwrap_error()

    assert(error == "Not enough args. Arguments required: exactly 1.")
  end

  test "you can only get information on one role at a time" do
    role("foo")
    role("bar")
    error = new_req(args: ["foo", "bar"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Too many args. Arguments required: exactly 1.")
  end

  test "information requires a string argument" do
    error = new_req(args: [123])
            |> send_req()
            |> unwrap_error()

    assert(error == "Arguments must be strings")
  end
end

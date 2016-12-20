defmodule Cog.Test.Commands.Relay.InfoTest do
  use Cog.CommandCase, command_module: Cog.Commands.Relay

  import Cog.Support.ModelUtilities, only: [relay: 2]
  alias Cog.Commands.Relay.Info

  test "getting information on a single relay works" do
    relay("foo", "footoken")

    response = new_req(args: ["foo"])
               |> send_req(Info)
               |> unwrap()

    assert(%{id: _,
             created_at: _,
             name: "foo",
             status: "disabled",
             relay_groups: []} = response)
  end

  test "getting information on a non-existent relay fails" do
    error = new_req(args: ["not-here"])
            |> send_req(Info)
            |> unwrap_error()

    assert(error == "Could not find 'relay' with the name 'not-here'")
  end

  test "getting information on a relay requires a relay name" do
    error = new_req(args: [])
            |> send_req(Info)
            |> unwrap_error()

    assert(error == "Not enough args. Arguments required: exactly 1.")
  end

  test "getting information on more than one relay fails" do
    relay("foo", "footoken")
    relay("bar", "bartoken")

    error = new_req(args: ["foo", "bar"])
            |> send_req(Info)
            |> unwrap_error()

    assert(error == "Too many args. Arguments required: exactly 1.")
  end

  test "getting information on a relay requires a string argument" do
    error = new_req(args: [123])
            |> send_req(Info)
            |> unwrap_error()

    assert(error == "Arguments must be strings")
  end

end

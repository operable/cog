defmodule Cog.Test.Commands.RelayTest do
  use Cog.CommandCase, command_module: Cog.Commands.Relay

  import Cog.Support.ModelUtilities, only: [relay: 2,
                                            relay_group: 1,
                                            add_relay_to_group: 2]
  alias Cog.Repository.Relays

  test "listing relays" do
    relay("foo", "footoken")
    relay("foo2", "otherfootoken")

    response = new_req(args: ["list"])
               |> send_req()
               |> unwrap()

    assert([%{name: "foo"},
            %{name: "foo2"}] = response)
  end

  test "listing relays with groups" do
    relay = relay("foo", "footoken")
    group = relay_group("foogroup")
    add_relay_to_group(group.id, relay.id)

    response = new_req(args: ["list"], options: %{"group" => true})
               |> send_req()
               |> unwrap()

    assert([%{name: "foo",
              relay_groups: [%{name: "foogroup"}]}] = response)
  end

  test "updating a relay name" do
    relay("foo", "footoken")

    response = new_req(args: ["update", "foo"], options: %{"name" => "bar"})
               |> send_req()
               |> unwrap()

    assert(%{name: "bar"} = response)

    relay = Relays.by_id(response.id)
            |> unwrap()
    assert(%{name: "bar"} = relay)
  end

  test "getting information on a single relay works" do
    relay("foo", "footoken")

    response = new_req(args: ["info", "foo"])
               |> send_req()
               |> unwrap()

    assert(%{id: _,
             created_at: _,
             name: "foo",
             status: "disabled",
             relay_groups: []} = response)
  end

  test "getting information on a non-existent relay fails" do
    error = new_req(args: ["info", "not-here"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Could not find 'relay' with the name 'not-here'")
  end

  test "getting information on a relay requires a relay name" do
    error = new_req(args: ["info"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Not enough args. Arguments required: exactly 1.")
  end

  test "getting information on more than one relay fails" do
    relay("foo", "footoken")
    relay("bar", "bartoken")

    error = new_req(args: ["info", "foo", "bar"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Too many args. Arguments required: exactly 1.")
  end

  test "getting information on a relay requires a string argument" do
    error = new_req(args: ["info", 123])
            |> send_req()
            |> unwrap_error()

    assert(error == "Arguments must be strings")
  end

  test "passing an unknown subcommand fails" do
    error = new_req(args: ["not-a-subcommand"])
            |> send_req()
            |> unwrap_error()

    assert(error == "Unknown subcommand 'not-a-subcommand'")
  end

end

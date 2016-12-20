defmodule Cog.Test.Commands.Relay.ListTest do
  use Cog.CommandCase, command_module: Cog.Commands.Relay

  import Cog.Support.ModelUtilities, only: [relay: 2,
                                            relay_group: 1,
                                            add_relay_to_group: 2]
  alias Cog.Commands.Relay.List

  test "listing relays" do
    relay("foo", "footoken")
    relay("foo2", "otherfootoken")

    response = new_req(args: [])
               |> send_req(List)
               |> unwrap()

    assert([%{name: "foo"},
            %{name: "foo2"}] = response)
  end

  test "listing relays with groups" do
    relay = relay("foo", "footoken")
    group = relay_group("foogroup")
    add_relay_to_group(group.id, relay.id)

    response = new_req(args: [], options: %{"group" => true})
               |> send_req(List)
               |> unwrap()

    assert([%{name: "foo",
              relay_groups: [%{name: "foogroup"}]}] = response)
  end
end

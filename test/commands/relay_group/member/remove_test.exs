defmodule Cog.Test.Commands.RelayGroup.Member.RemoveTest do
  use Cog.CommandCase, command_module: Cog.Commands.RelayGroup

  import Cog.Support.ModelUtilities, only: [relay_group: 1,
                                            relay: 2,
                                            add_relay_to_group: 2]
  alias Cog.Repository.RelayGroups
  alias Cog.Commands.RelayGroup.Member

  test "removing relays from relay groups" do
    relay_group = relay_group("relay_group")
    relay = relay("relay", "foo")
    add_relay_to_group(relay_group.id, relay.id)

    response = new_req(args: ["relay_group", "relay"])
               |> send_req(Member.Remove)
               |> unwrap()

    assert(%{name: "relay_group",
             relays: []} = response)

    relay_group = RelayGroups.by_id!(response.id)
    assert(%{name: "relay_group",
             relays: []} = relay_group)
  end
end

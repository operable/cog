defmodule Cog.Test.Commands.RelayGroup.Member.AddTest do
  use Cog.CommandCase, command_module: Cog.Commands.RelayGroup

  import Cog.Support.ModelUtilities, only: [relay_group: 1, relay: 2]
  alias Cog.Commands.RelayGroup.Member
  alias Cog.Repository.RelayGroups

  test "adding relays to relay groups" do
    relay_group("relay_group")
    relay("relay", "foo")

    response = new_req(args: ["relay_group", "relay"])
               |> send_req(Member.Add)
               |> unwrap()

    assert(%{name: "relay_group",
             relays: [%{name: "relay"}]} = response)

    relay_group = RelayGroups.by_id!(response.id)
    assert(%{name: "relay_group",
             relays: [%{name: "relay"}]} = relay_group)
  end
end

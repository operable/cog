defmodule Cog.Test.Commands.RelayGroup.Member.AssignTest do
  use Cog.CommandCase, command_module: Cog.Commands.RelayGroup

  import Cog.Support.ModelUtilities, only: [relay_group: 1, bundle_version: 1]
  alias Cog.Repository.RelayGroups
  alias Cog.Commands.RelayGroup.Member

  test "assigning bundles to relay groups" do
    relay_group("relay_group")
    bundle_version("bundle").bundle

    response = new_req(args: ["relay_group", "bundle"])
               |> send_req(Member.Assign)
               |> unwrap()

    assert(%{name: "relay_group",
             bundles: [%{name: "bundle"}]} = response)

    relay_group = RelayGroups.by_id!(response.id)
    assert(%{name: "relay_group",
             bundles: [%{name: "bundle"}]} = relay_group)
  end
end

defmodule Cog.Test.Commands.RelayGroup.Member.UnassignTest do
  use Cog.CommandCase, command_module: Cog.Commands.RelayGroup

  import Cog.Support.ModelUtilities, only: [relay_group: 1,
                                            bundle_version: 1,
                                            assign_bundle_to_group: 2]
  alias Cog.Repository.RelayGroups
  alias Cog.Commands.RelayGroup.Member

  test "unassigning bundles from relay groups" do
    relay_group = relay_group("relay_group")
    bundle = bundle_version("bundle").bundle
    assign_bundle_to_group(relay_group.id, bundle.id)

    response = new_req(args: ["relay_group", "bundle"])
               |> send_req(Member.Unassign)
               |> unwrap()

    assert(%{name: "relay_group",
             bundles: []} = response)

    relay_group = RelayGroups.by_id!(response.id)
    assert(%{name: "relay_group",
             bundles: []} = relay_group)
  end
end

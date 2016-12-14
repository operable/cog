defmodule Cog.Test.Commands.RelayGroup.RenameTest do
  use Cog.CommandCase, command_module: Cog.Commands.RelayGroup

  import Cog.Support.ModelUtilities, only: [relay_group: 1]
  alias Cog.Repository.RelayGroups
  alias Cog.Commands.RelayGroup.Rename

  test "renaming a relay group" do
    %{id: id} = relay_group("relay_group")

    response = new_req(args: ["relay_group", "rly_grp"])
               |> send_req(Rename)
               |> unwrap()

    assert(%{old_name: "relay_group",
             relay_group: %{name: "rly_grp",
                            id: ^id}} = response)

    relay_group = RelayGroups.by_id!(id)
    assert(relay_group.name == "rly_grp")
  end
end

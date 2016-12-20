defmodule Cog.Test.Commands.RelayGroup.DeleteTest do
  use Cog.CommandCase, command_module: Cog.Commands.RelayGroup

  import Cog.Support.ModelUtilities, only: [relay_group: 1]
  alias Cog.Repository.RelayGroups
  alias Cog.Commands.RelayGroup.Delete

  test "deleting a relay group" do
    relay_group("relay_group")

    response = new_req(args: ["relay_group"])
               |> send_req(Delete)
               |> unwrap()

    assert(%{name: "relay_group"} = response)

    relay_group = RelayGroups.by_id(response.id)
                  |> unwrap_error()

    assert(relay_group == :not_found)
  end
end

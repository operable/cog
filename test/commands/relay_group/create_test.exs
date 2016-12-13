defmodule Cog.Test.Commands.RelayGroup.CreateTest do
  use Cog.CommandCase, command_module: Cog.Commands.RelayGroup

  alias Cog.Commands.RelayGroup.Create
  alias Cog.Repository.RelayGroups

  test "creating a relay group" do
    response = new_req(args: ["foogroup"])
               |> send_req(Create)
               |> unwrap()

    assert(%{name: "foogroup"} = response)

    relay_group = RelayGroups.by_id!(response.id)
    assert(relay_group.name == "foogroup")
  end
end

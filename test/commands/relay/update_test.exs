defmodule Cog.Test.Commands.Relay.UpdateTest do
  use Cog.CommandCase, command_module: Cog.Commands.Relay

  import Cog.Support.ModelUtilities, only: [relay: 2]
  alias Cog.Commands.Relay.Update
  alias Cog.Repository.Relays

  test "updating a relay name" do
    relay("foo", "footoken")

    response = new_req(args: ["foo"], options: %{"name" => "bar"})
               |> send_req(Update)
               |> unwrap()

    assert(%{name: "bar"} = response)

    relay = Relays.by_id(response.id)
            |> unwrap()
    assert(%{name: "bar"} = relay)
  end
end

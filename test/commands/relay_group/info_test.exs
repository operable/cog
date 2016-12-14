defmodule Cog.Test.Commands.RelayGroup.InfoTest do
  use Cog.CommandCase, command_module: Cog.Commands.RelayGroup

  import Cog.Support.ModelUtilities, only: [relay_group: 1]
  alias Cog.Commands.RelayGroup.Info

  test "viewing info of a relay group" do
    relay_group("relay_group")

    response = new_req(args: ["relay_group"])
               |> send_req(Info)
               |> unwrap()

    assert([%{name: "relay_group"}] = response)
  end
end

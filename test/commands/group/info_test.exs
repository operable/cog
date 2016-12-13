defmodule Cog.Test.Commands.Group.InfoTest do
  use Cog.CommandCase, command_module: Cog.Commands.Group

  alias Cog.Commands.Group.Info
  import Cog.Support.ModelUtilities, only: [group: 1]

  test "can get info" do
    group("info_group")

    {:ok, response} =
      new_req(args: ["info_group"])
      |> send_req(Info)

    assert(%{name: "info_group"} = response)
  end
end

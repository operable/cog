defmodule Cog.Test.Commands.Group.DeleteTest do
  use Cog.CommandCase, command_module: Cog.Commands.Group

  alias Cog.Commands.Group.Delete
  import Cog.Support.ModelUtilities, only: [group: 1]

  test "can be deleted" do
    group("deleted_group")

    {:ok, response} =
      new_req(args: ["deleted_group"])
      |> send_req(Delete)

    assert(%{name: "deleted_group"} = response)
  end
end

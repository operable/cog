defmodule Cog.Test.Commands.Group.CreateTest do
  use Cog.CommandCase, command_module: Cog.Commands.Group

  alias Cog.Commands.Group.Create
  import Cog.Support.ModelUtilities, only: [group: 1]

  test "can be created" do
    {:ok, response} =
      new_req(args: ["created_group"])
      |> send_req(Create)

    assert(%{name: "created_group"} = response)
  end

  test "can't create a group with a duplicate name" do
    group("duplicate_group")

    {:error, error} =
      new_req(args: ["duplicate_group"])
      |> send_req(Create)

    assert(error == "name: has already been taken")
  end
end

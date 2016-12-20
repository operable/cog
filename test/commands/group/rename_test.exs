defmodule Cog.Test.Commands.Group.RenameTest do
  use Cog.CommandCase, command_module: Cog.Commands.Group

  alias Cog.Commands.Group.Rename
  import Cog.Support.ModelUtilities, only: [group: 1]

  test "can be renamed" do
    group("renamed_group")

    {:ok, response} =
      new_req(args: ["renamed_group", "has_been_renamed"])
      |> send_req(Rename)

    assert(%{name: "has_been_renamed"} = response)
  end

  test "can't rename a group with another groups name" do
    group("group_to_rename")
    group("already_named")

    {:error, error} =
      new_req(args: ["group_to_rename", "already_named"])
      |> send_req(Rename)

    assert(error == "name has already been taken")
  end

  test "can't rename a group that doesn't exist" do
    {:error, error} =
      new_req(args: ["not-here", "monkeys"])
      |> send_req(Rename)

    assert(error == "Could not find 'group' with the name 'not-here'")
  end

  test "can't rename without the proper args" do
    group("not_enough_args")

    {:error, error} =
      new_req(args: ["not_enough_args"])
      |> send_req(Rename)

    assert(error == "Not enough args. Arguments required: exactly 2.")

    {:error, error} =
      new_req(args: [])
      |> send_req(Rename)

    assert(error == "Not enough args. Arguments required: exactly 2.")
  end

  test "can't name a group with a number" do
    group("number_group")

    {:error, error} =
      new_req(args: ["number_group", 123])
      |> send_req(Rename)

    assert(error == "Arguments must be strings")
  end
end

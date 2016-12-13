defmodule Cog.Test.Commands.Group.Member.AddTest do
  use Cog.CommandCase, command_module: Cog.Commands.Group

  alias Cog.Commands.Group.Member
  import Cog.Support.ModelUtilities, only: [user: 1, group: 1]

  setup [:with_user, :with_group]

  test "can be added to a group", %{user: user, group: group} do
    {:ok, response} =
      new_req(args: [group.name, user.username])
      |> send_req(Member.Add)

    assert(is_group_user?(response, user.username))
  end

  test "can not add an unknown user to a group", %{group: group} do
    {:error, error} =
      new_req(args: [group.name, "bob"])
      |> send_req(Member.Add)

    assert(error == "Could not find 'user' with the name 'bob'")
  end

  test "can not add to an unknown group", %{user: user} do
    {:error, error} =
      new_req(args: ["bad_group", user.username])
      |> send_req(Member.Add)

    assert(error == "Could not find 'user group' with the name 'bad_group'")
  end

  test "must supply the proper number of args", %{group: group} do
    # TODO: This should probably return an error instead of a map with an
    # error key. Probably something left over from the early templating days.
    {:error, error} =
      new_req(args: [group.name])
      |> send_req(Member.Add)

    assert(error == "Not enough args. Arguments required: minimum of 2.")
  end

  #### Setup Functions ####

  defp with_user(_),
    do: [user: user("belf")]

  defp with_group(_),
    do: [group: group("elves")]

  #### Helper Functions ####

  defp is_group_user?(%Cog.Models.Group{}=group, username) do
    Enum.map(group.user_membership, &(&1.member.username))
    |> Enum.member?(username)
  end
  defp is_group_user?(%{members: members}, username) do
    Enum.map(members, &(&1.username))
    |> Enum.member?(username)
  end
end

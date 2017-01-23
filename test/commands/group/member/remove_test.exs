defmodule Cog.Test.Commands.Group.Member.RemoveTest do
  use Cog.CommandCase, command_module: Cog.Commands.Group

  alias Cog.Commands.Group.Member
  import Cog.Support.ModelUtilities,
    only: [user: 1, group: 1, add_to_group: 2]

    setup [:with_user, :with_group]

    test "can be removed from a group", %{user: user, group: group} do
      # Add the user to the group
      group = add_to_group(group, user)

      # Make sure that it's there
      assert(is_group_user?(group, user.username))

      # Then remove it via the group command
      {:ok, response} =
        new_req(args: [group.name, user.username])
        |> send_req(Member.Remove)

      refute(is_group_user?(response, user.username))
    end

  defp with_user(_),
    do: [user: user("belf")]

  defp with_group(_),
    do: [group: group("elves")]

  defp is_group_user?(%Cog.Models.Group{}=group, username) do
    Enum.map(group.users, &(&1.username))
    |> Enum.member?(username)
  end
  defp is_group_user?(%{members: members}, username) do
    Enum.map(members, &(&1.username))
    |> Enum.member?(username)
  end
end

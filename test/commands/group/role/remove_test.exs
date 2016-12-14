defmodule Cog.Test.Commands.Group.Role.RemoveTest do
  use Cog.CommandCase, command_module: Cog.Commands.Group

  alias Cog.Commands.Group.Role
  import Cog.Support.ModelUtilities, only: [group: 1,
                                            role: 1,
                                            add_to_group: 2]

  setup [:with_role, :with_group]

  test "can be removed from a group", %{role: role, group: group} do
    # Add the role to the group
    group = add_to_group(group, role)

    # Make sure that it's there
    assert(is_group_role?(group, role.name))

    # Then remove it via the group command
    {:ok, response} =
      new_req(args: [group.name, role.name])
      |> send_req(Role.Remove)

    refute(is_group_role?(response, role.name))
  end

  defp with_group(_),
    do: [group: group("elves")]

  defp with_role(_),
    do: [role: role("grand_elves")]

  defp is_group_role?(%Cog.Models.Group{}=group, rolename) do
    Enum.map(group.roles, &(&1.name))
    |> Enum.member?(rolename)
  end
  defp is_group_role?(%{roles: roles}, rolename) do
    Enum.map(roles, &(&1.name))
    |> Enum.member?(rolename)
  end
end

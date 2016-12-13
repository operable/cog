defmodule Cog.Test.Commands.Group.Role.AddTest do
  use Cog.CommandCase, command_module: Cog.Commands.Group

  alias Cog.Commands.Group.Role
  import Cog.Support.ModelUtilities, only: [group: 1, role: 1]

  describe "roles" do
    setup [:with_role, :with_group]

    test "can be added to a group", %{role: role, group: group} do
      {:ok, response} =
        new_req(args: [group.name, role.name])
        |> send_req(Role.Add)

      assert(is_group_role?(response, role.name))
    end
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

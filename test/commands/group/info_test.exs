defmodule Cog.Test.Commands.Group.InfoTest do
  use Cog.CommandCase, command_module: Cog.Commands.Group

  alias Cog.Commands.Group.Info
  import Cog.Support.ModelUtilities, only: [group: 1,
                                            user: 1,
                                            role: 1,
                                            add_to_group: 2]

  test "can get info" do
    group("info_group")

    {:ok, response} =
      new_req(args: ["info_group"])
      |> send_req(Info)

    assert(%{name: "info_group",
             roles: [],
             members: []} = response)
  end

  test "can get info with members and roles" do
    group("info_group")
    |> add_to_group(role("role1"))
    |> add_to_group(role("role2"))
    |> add_to_group(user("user1"))
    |> add_to_group(user("user2"))

    {:ok, response} =
      new_req(args: ["info_group"])
      |> send_req(Info)

    assert(%{name: "info_group",
             roles: [%{name: "role1"},
                     %{name: "role2"}],
             members: [%{username: "user1"},
                       %{username: "user2"}]} = response)
  end
end

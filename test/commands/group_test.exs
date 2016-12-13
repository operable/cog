defmodule Cog.Test.Commands.GroupTest do
  use Cog.CommandCase, command_module: Cog.Commands.Group

  alias Cog.Commands.Group.{List, Create, Delete, Rename, Info, Member}
  import Cog.Support.ModelUtilities, only: [user: 1,
                                            group: 1,
                                            role: 1,
                                            add_to_group: 2]
  describe "group subcommands" do

    test "can't pass an unknown subcommand" do
      {:error, error} =
        new_req(args: ["not-a-subcommand"])
        |> send_req()

      assert(error == "Unknown subcommand 'not-a-subcommand'")
    end

  end

  describe "group CRUD" do

    test "can be created" do
      {:ok, response} =
        new_req(args: ["created_group"])
        |> send_req(Create)

      assert(%{name: "created_group"} = response)
    end

    test "can be deleted" do
      group("deleted_group")

      {:ok, response} =
        new_req(args: ["deleted_group"])
        |> send_req(Delete)

      assert(%{name: "deleted_group"} = response)
    end

    test "can be renamed" do
      group("renamed_group")

      {:ok, response} =
        new_req(args: ["renamed_group", "has_been_renamed"])
        |> send_req(Rename)

      assert(%{name: "has_been_renamed"} = response)
    end

    test "can get info" do
      group("info_group")

      {:ok, response} =
        new_req(args: ["info_group"])
        |> send_req(Info)

      assert(%{name: "info_group"} = response)
    end

    test "can be listed" do
      Enum.each(1..3, &group("group#{&1}"))

      {:ok, response} =
        new_req(args: [])
        |> send_req(List)

      response = Enum.sort_by(response, &(&1.name))

      assert([%{name: "group1"},
              %{name: "group2"},
              %{name: "group3"}] = response)
    end

    test "can't create a group with a duplicate name" do
      group("duplicate_group")

      {:error, error} =
        new_req(args: ["duplicate_group"])
        |> send_req(Create)

      assert(error == "name: has already been taken")
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

  describe "users" do
    setup [:with_user, :with_group]

    test "can be added to a group", %{user: user, group: group} do
      {:ok, response} =
        new_req(args: [group.name, user.username])
        |> send_req(Member.Add)

      assert(is_group_user?(response, user.username))
    end

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

  end

  describe "roles" do

    setup [:with_role, :with_group]

    test "can be added to a group", %{role: role, group: group} do
      {:ok, response} =
        new_req(args: ["role", "add", group.name, role.name])
        |> send_req()

      assert(is_group_role?(response, role.name))
    end

    test "can be removed from a group", %{role: role, group: group} do
      # Add the role to the group
      group = add_to_group(group, role)

      # Make sure that it's there
      assert(is_group_role?(group, role.name))

      # Then remove it via the group command
      {:ok, response} =
        new_req(args: ["role", "remove", group.name, role.name])
        |> send_req()

      refute(is_group_role?(response, role.name))
    end

  end

  #### Setup Functions ####

  defp with_user(_),
    do: [user: user("belf")]

  defp with_group(_),
    do: [group: group("elves")]

  defp with_role(_),
    do: [role: role("grand_elves")]

  #### Helper Functions ####

  defp is_group_user?(%Cog.Models.Group{}=group, username) do
    Enum.map(group.user_membership, &(&1.member.username))
    |> Enum.member?(username)
  end
  defp is_group_user?(%{members: members}, username) do
    Enum.map(members, &(&1.username))
    |> Enum.member?(username)
  end

  defp is_group_role?(%Cog.Models.Group{}=group, rolename) do
    Enum.map(group.roles, &(&1.name))
    |> Enum.member?(rolename)
  end
  defp is_group_role?(%{roles: roles}, rolename) do
    Enum.map(roles, &(&1.name))
    |> Enum.member?(rolename)
  end

end

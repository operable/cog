defmodule Integration.Commands.GroupTest do
  use Cog.AdapterCase, adapter: "test"

  alias Cog.Models.Group
  alias Cog.Repository.Groups

  setup do
    user = user("belf", first_name: "Buddy", last_name: "Elf")
    |> with_chat_handle_for("test")
    |> with_permission("operable:manage_users")
    |> with_permission("operable:manage_groups")

    {:ok, %{user: user}}
  end

  test "adding and removing users to groups", %{user: user} do
    response = send_message(user, "@bot: operable:group member add elves #{user.username}")
    assert_error_message_contains(response, "Whoops! An error occurred. Could not find 'user group' with the name 'elves'")

    [response] = send_message(user, "@bot: operable:group create elves")
    assert response.name == "elves"

    response = send_message(user, "@bot: operable:group member add elves papa_elf")
    assert_error_message_contains(response, "Whoops! An error occurred. Could not find 'user' with the name 'papa_elf'")

    response = send_message(user, "@bot: operable:group member add elves")
    assert_error_message_contains(response, "Missing required args. At a minimum you must include the user group and at least one user name to add")

    [response] = send_message(user, "@bot: operable:group member add elves belf")
    member = hd(response.members)
    assert member.username == "belf"

    [response] = send_message(user, "@bot: operable:group member remove elves belf")
    assert length(response.members) == 0
  end

  test "adding and removing roles to groups", %{user: user} do
    group("cheer")
    role("admin")

    [response] = send_message(user, "@bot: operable:group role add cheer admin")
    assert response.name == "cheer"

    [response] = send_message(user, "@bot: operable:group info cheer")
    assert hd(response.roles).name == "admin"

    [response] = send_message(user, "@bot: operable:group role remove cheer admin")
    assert response.name == "cheer"

    [response] = send_message(user, "@bot: operable:group info cheer")
    assert length(response.roles) == 0
  end

  test "getting group info", %{user: user} do
    group("cheer")

    [response] = send_message(user, "@bot: operable:group info cheer")
    assert response.name == "cheer"
  end

  test "creating a group", %{user: user} do
    [response] = send_message(user, "@bot: operable:group create test")
    assert response.name == "test"

    response = send_message(user, "@bot: operable:group create test")
    assert_error_message_contains(response, "name: has already been taken")
  end

  test "errors using the group command", %{user: user} do
    response = send_message(user, "@bot: operable:group create")
    assert_error_message_contains(response, "Missing required argument: group_name")

    response = send_message(user, "@bot: operable:group member add belf")
    assert_error_message_contains(response, "Missing required args. At a minimum you must include the user group and at least one user name to add")
  end

  test "deleting a group", %{user: user} do
    cheer = group("cheer")

    [response] = send_message(user, "@bot: operable:group member add cheer belf")
    assert response.id == cheer.id
    assert response.name == cheer.name
    member = hd(response.members)
    assert member.email_address == user.email_address
    assert member.first_name == user.first_name
    assert member.last_name == user.last_name

    [response] = send_message(user, "@bot: operable:group delete cheer")
    assert response.name == "cheer"

    response = send_message(user, "@bot: operable:group member remove cheer belf")
    assert_error_message_contains(response, "Whoops! An error occurred. Could not find 'user group' with the name 'cheer'")
  end

  test "listing group", %{user: user} do
    group("elves")
    cheer = group("cheer")

    [response] = send_message(user, "@bot: operable:group member add cheer belf")
    assert response.id == cheer.id
    assert response.name == cheer.name
    member = hd(response.members)
    assert member.email_address == user.email_address
    assert member.first_name == user.first_name
    assert member.last_name == user.last_name

    response = send_message(user, "@bot: operable:group list")
    group_names = Enum.map(response, &(&1.name)) |> Enum.sort
    assert group_names == ["cheer", "cog-admin", "elves"]

    [response] = send_message(user, "@bot: operable:group delete cheer")
    assert response.name == "cheer"

    response = send_message(user, "@bot: operable:group list")
    group_names = Enum.map(response, &(&1.name)) |> Enum.sort
    assert group_names == ["cog-admin", "elves"]

    response = send_message(user, "@bot: operable:group")
    group_names = Enum.map(response, &(&1.name)) |> Enum.sort
    assert group_names == ["cog-admin", "elves"]
  end

  test "renaming a group works", %{user: user} do
    %Group{id: id} = group("foo")

    [payload] = send_message(user, "@bot: operable:group rename foo bar")
    assert %{id: ^id,
             name: "bar",
             old_name: "foo"} = payload

    assert {:error, :not_found} = Groups.by_name("foo")
    assert {:ok, %Group{id: ^id}} = Groups.by_name("bar")
  end

  test "the cog-admin group cannot be renamed", %{user: user} do
    response = send_message(user, "@bot: operable:group rename cog-admin monkeys")
    assert_error_message_contains(response , "Cannot alter protected group cog-admin")
  end

  test "renaming a non-existent group fails", %{user: user} do
    response = send_message(user, "@bot: operable:group rename not-here monkeys")
    assert_error_message_contains(response , "Could not find 'group' with the name 'not-here'")
  end

  test "renaming to an already-existing group fails", %{user: user} do
    group("foo")
    group("bar")

    response = send_message(user, "@bot: operable:group rename foo bar")
    assert_error_message_contains(response , "name has already been taken")
  end

  test "renaming requires a new name", %{user: user} do
    group("foo")
    response = send_message(user, "@bot: operable:group rename foo")
    assert_error_message_contains(response , "Not enough args. Arguments required: exactly 2.")
  end

  test "rename requires a group and a name", %{user: user} do
    response = send_message(user, "@bot: operable:group rename")
    assert_error_message_contains(response , "Not enough args. Arguments required: exactly 2.")
  end

  test "renaming requires string arguments", %{user: user} do
    response = send_message(user, "@bot: operable:group rename 123 456")
    assert_error_message_contains(response , "Arguments must be strings")
  end

  test "passing an unknown subcommand fails", %{user: user} do
    response = send_message(user, "@bot: operable:group not-a-subcommand")
    assert_error_message_contains(response, "Whoops! An error occurred. Unknown subcommand 'not-a-subcommand'")
  end

end

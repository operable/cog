defmodule Integration.Commands.GroupTest do
  use Cog.AdapterCase, adapter: "test"

  setup do
    user = user("belf", first_name: "Buddy", last_name: "Elf")
    |> with_chat_handle_for("test")
    |> with_permission("operable:manage_users")
    |> with_permission("operable:manage_groups")

    {:ok, %{user: user}}
  end

  test "adding a user to a group", %{user: user} do
    response = send_message(user, "@bot: operable:group member add elves #{user.username}")
    assert_error_message_contains(response, "Whoops! An error occurred. Could not find 'user group' with the name 'elves'")

    [response] = send_message(user, "@bot: operable:group create elves")
    |> decode_payload
    assert response.name == "elves"

    response = send_message(user, "@bot: operable:group member add elves papa_elf")
    assert_error_message_contains(response, "Whoops! An error occurred. Could not find 'user' with the name 'papa_elf'")

    response = send_message(user, "@bot: operable:group member add elves")
    assert_error_message_contains(response, "Missing required args. At a minimum you must include the user group and at least one user name to add")

    [response] = send_message(user, "@bot: operable:group member add elves belf")
    |> decode_payload
    member = Map.get(hd(response.user_membership), :member)
    assert member.username == "belf"
  end

  test "getting group info", %{user: user} do
    cheer = group("cheer")

    [response] = send_message(user, "@bot: operable:group info cheer")
    |> decode_payload
    assert response.name == "cheer"
  end

  test "creating a group", %{user: user} do
    [response] = send_message(user, "@bot: operable:group create test")
    |> decode_payload
    assert response.name == "test"

    response = send_message(user, "@bot: operable:group create test")
    assert_error_message_contains(response, "Whoops! An error occurred. name: The group name is already in use.")
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
    |> decode_payload
    assert response.id == cheer.id
    assert response.name == cheer.name
    member = Map.get(hd(response.user_membership), :member)
    assert member.email_address == user.email_address
    assert member.first_name == user.first_name
    assert member.last_name == user.last_name

    [response] = send_message(user, "@bot: operable:group delete cheer")
    |> decode_payload
    assert response.name == "cheer"

    response = send_message(user, "@bot: operable:group member remove cheer belf")
    assert_error_message_contains(response, "Whoops! An error occurred. Could not find 'user group' with the name 'cheer'")
  end

  test "listing group", %{user: user} do
    group("elves")
    cheer = group("cheer")

    [response] = send_message(user, "@bot: operable:group member add cheer belf")
    |> decode_payload
    assert response.id == cheer.id
    assert response.name == cheer.name
    member = Map.get(hd(response.user_membership), :member)
    assert member.email_address == user.email_address
    assert member.first_name == user.first_name
    assert member.last_name == user.last_name

    response = send_message(user, "@bot: operable:group list")
    |> decode_payload
    group_names = Enum.map(response, &(&1.name)) |> Enum.sort
    assert group_names == ["cheer", "cog-admin", "elves"]

    [response] = send_message(user, "@bot: operable:group delete cheer")
    |> decode_payload
    assert response.name == "cheer"

    response = send_message(user, "@bot: operable:group list")
    |> decode_payload
    group_names = Enum.map(response, &(&1.name)) |> Enum.sort
    assert group_names == ["cog-admin", "elves"]

    response = send_message(user, "@bot: operable:group")
    |> decode_payload
    group_names = Enum.map(response, &(&1.name)) |> Enum.sort
    assert group_names == ["cog-admin", "elves"]
  end
end

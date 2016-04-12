defmodule Integration.GroupTest do
  use Cog.AdapterCase, adapter: "test"

  setup do
    user = user("belf", first_name: "Buddy", last_name: "Elf")
    |> with_chat_handle_for("test")
    |> with_permission("operable:manage_users")
    |> with_permission("operable:manage_groups")

    {:ok, %{user: user}}
  end

  test "adding a user to a group", %{user: user} do
    response = send_message(user, "@bot: operable:group --add --user=#{user.username} elves")
    assert_error_message_contains(response, "Whoops! An error occurred. ERROR! Could not find group `elves`")

    response = send_message(user, "@bot: operable:group --create elves")
    assert_payload(response, %{body: ["The group `elves` has been created."]})

    response = send_message(user, "@bot: operable:group --add --user=papa_elf elves")
    assert_error_message_contains(response, "Whoops! An error occurred. ERROR! Could not find user `papa_elf`")

    response = send_message(user, "@bot: operable:group --add elves")
    assert_error_message_contains(response, "Whoops! An error occurred. ERROR! Must specify a target to act upon. See `operable:help operable:group` for more details.")

    response = send_message(user, "@bot: operable:group --add --user=belf elves")
    assert_payload(response, %{body: ["Added the user `belf` to the group `elves`"]})
  end

  test "creating a group", %{user: user} do
    response = send_message(user, "@bot: operable:group --create test")
    assert_payload(response, %{body: ["The group `test` has been created."]})

    response = send_message(user, "@bot: operable:group --create test")
    assert_error_message_contains(response, "Whoops! An error occurred. ERROR! The group `test` already exists.")
  end

  test "errors using the group command", %{user: user} do
    response = send_message(user, "@bot: operable:group --create ")
    assert_error_message_contains(response, "Whoops! An error occurred. ERROR! Unable to create ``:\nMissing name")

    response = send_message(user, "@bot: operable:group --add --user=belf")
    assert_error_message_contains(response, "Whoops! An error occurred. ERROR! Must specify a group to modify.")
  end

  test "dropping a group", %{user: user} do
    group("cheer")

    response = send_message(user, "@bot: operable:group --add --user=belf cheer")
    assert_payload(response, %{body: ["Added the user `belf` to the group `cheer`"]})

    response = send_message(user, "@bot: operable:group --drop cheer")
    assert_payload(response, %{body: ["The group `cheer` has been deleted."]})

    response = send_message(user, "@bot: operable:group --remove --user=belf cheer")
    assert_error_message_contains(response, "Whoops! An error occurred. ERROR! Could not find group `cheer`")
  end

  test "listing group", %{user: user} do
    group("elves")
    group("cheer")

    response = send_message(user, "@bot: operable:group --add --user=belf cheer")
    assert_payload(response, %{body: ["Added the user `belf` to the group `cheer`"]})

    response = send_message(user, "@bot: operable:group --list")
    assert_payload(response, %{body: ["The following are the available groups: \n* cheer\n* elves\n* cog-admin\n"]})

    response = send_message(user, "@bot: operable:group --drop cheer")
    assert_payload(response, %{body: ["The group `cheer` has been deleted."]})

    response = send_message(user, "@bot: operable:group --list")
    assert_payload(response, %{body: ["The following are the available groups: \n* elves\n* cog-admin\n"]})
  end
end

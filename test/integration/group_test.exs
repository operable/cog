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
    assert response["data"]["response"] == "@belf Whoops! An error occurred. ERROR! Could not find group `elves`"

    response = send_message(user, "@bot: operable:group --create elves")
    assert response["data"]["response"] == "The group `elves` has been created."

    response = send_message(user, "@bot: operable:group --add --user=papa_elf elves")
    assert response["data"]["response"] == "@belf Whoops! An error occurred. ERROR! Could not find user `papa_elf`"

    response = send_message(user, "@bot: operable:group --add elves")
    assert response["data"]["response"] == "@belf Whoops! An error occurred. ERROR! Must specify a target to act upon. See `operable:help operable:group` for more details."

    response = send_message(user, "@bot: operable:group --add --user=belf elves")
    assert response["data"]["response"] == "Added the user `belf` to the group `elves`"
  end

  test "creating a group", %{user: user} do
    response = send_message(user, "@bot: operable:group --create test")
    assert response["data"]["response"] == "The group `test` has been created."

    response = send_message(user, "@bot: operable:group --create test")
    assert response["data"]["response"] == "@belf Whoops! An error occurred. ERROR! The group `test` already exists."
  end

  test "adding a group to a group", %{user: user} do
    group = group("elves")

    response = send_message(user, "@bot: operable:group --add --group=#{group.name} cheer")
    assert response["data"]["response"] == "@belf Whoops! An error occurred. ERROR! Could not find group `cheer`"

    response = send_message(user, "@bot: operable:group --create cheer")
    assert response["data"]["response"] == "The group `cheer` has been created."

    response = send_message(user, "@bot: operable:group --add --group=humbug cheer")
    assert response["data"]["response"] == "@belf Whoops! An error occurred. ERROR! Could not find group `humbug`"

    response = send_message(user, "@bot: operable:group --add --group=#{group.name} cheer")
    assert response["data"]["response"] == "Added the group `elves` to the group `cheer`"
  end

  test "errors using the group command", %{user: user} do
    response = send_message(user, "@bot: operable:group --create ")
    assert response["data"]["response"] == "@belf Whoops! An error occurred. ERROR! Unable to create ``:\nMissing name"

    response = send_message(user, "@bot: operable:group --add --user=belf")
    assert response["data"]["response"] == "@belf Whoops! An error occurred. ERROR! Must specify a group to modify."
  end

  test "dropping a group", %{user: user} do
    group("cheer")
    response = send_message(user, "@bot: operable:group --add --user=belf cheer")
    assert response["data"]["response"] == "Added the user `belf` to the group `cheer`"

    response = send_message(user, "@bot: operable:group --drop cheer")
    assert response["data"]["response"] == "The group `cheer` has been deleted."

    response = send_message(user, "@bot: operable:group --remove --user=belf cheer")
    assert response["data"]["response"] == "@belf Whoops! An error occurred. ERROR! Could not find group `cheer`"
  end

  test "removing a group", %{user: user} do
    group("elves")

    response = send_message(user, "@bot: operable:group --add --group=elves cheer")
    assert response["data"]["response"] == "@belf Whoops! An error occurred. ERROR! Could not find group `cheer`"

    group("cheer")
    response = send_message(user, "@bot: operable:group --add --group=elves cheer")
    assert response["data"]["response"] == "Added the group `elves` to the group `cheer`"

    response = send_message(user, "@bot: operable:group --remove --group=elves cheer")
    assert response["data"]["response"] == "Removed the group `elves` from the group `cheer`"
  end

  test "listing group", %{user: user} do
    group("elves")
    group("cheer")

    response = send_message(user, "@bot: operable:group --add --group=elves cheer")
    assert response["data"]["response"] == "Added the group `elves` to the group `cheer`"

    response = send_message(user, "@bot: operable:group --add --user=belf cheer")
    assert response["data"]["response"] == "Added the user `belf` to the group `cheer`"

    response = send_message(user, "@bot: operable:group --list")
    assert response["data"]["response"] == "The following are the available groups: \n* cheer\n* elves\n"

    response = send_message(user, "@bot: operable:group --drop cheer")
    assert response["data"]["response"] == "The group `cheer` has been deleted."

    response = send_message(user, "@bot: operable:group --list")
    assert response["data"]["response"] == "The following are the available groups: \n* elves\n"
  end
end

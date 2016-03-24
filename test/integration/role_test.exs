defmodule Integration.RoleTest do
  use Cog.AdapterCase, adapter: "test"

  setup do
    user = user("belf", first_name: "Buddy", last_name: "Elf")
    |> with_chat_handle_for("test")
    |> with_permission("operable:manage_users")
    |> with_permission("operable:manage_groups")
    |> with_permission("operable:manage_roles")

    {:ok, %{user: user}}
  end

  test "granting a role to a user", %{user: user} do
    response = send_message(user, "@bot: operable:role --grant --user=#{user.username} cheer") |> Map.fetch!("response")
    assert response == "@belf Whoops! An error occurred. ERROR! Could not find role `cheer`"

    response = send_message(user, "@bot: operable:role --create cheer") |> Map.fetch!("response")
    assert response == "The role `cheer` has been created."

    response = send_message(user, "@bot: operable:role --grant --user=papa_elf cheer") |> Map.fetch!("response")
    assert response == "@belf Whoops! An error occurred. ERROR! Could not find user `papa_elf`"

    response = send_message(user, "@bot: operable:role --grant cheer") |> Map.fetch!("response")
    assert response == "@belf Whoops! An error occurred. ERROR! Must specify a target to act upon. See `operable:help operable:role` for more details."

    response = send_message(user, "@bot: operable:role --grant --user=belf cheer") |> Map.fetch!("response")
    assert response == "Granted role `cheer` to user `belf`"
  end

  test "creating a role", %{user: user} do
    response = send_message(user, "@bot: operable:role --create test") |> Map.fetch!("response")
    assert response == "The role `test` has been created."

    response = send_message(user, "@bot: operable:role --create test") |> Map.fetch!("response")
    assert response == "@belf Whoops! An error occurred. ERROR! The role `test` already exists."
  end

  test "granting a role to a group", %{user: user} do
    group = group("elves")

    response = send_message(user, "@bot: operable:role --grant --group=#{group.name} cheer") |> Map.fetch!("response")
    assert response == "@belf Whoops! An error occurred. ERROR! Could not find role `cheer`"

    response = send_message(user, "@bot: operable:role --create cheer") |> Map.fetch!("response")
    assert response == "The role `cheer` has been created."

    response = send_message(user, "@bot: operable:role --grant --group=humbug cheer") |> Map.fetch!("response")
    assert response == "@belf Whoops! An error occurred. ERROR! Could not find group `humbug`"

    response = send_message(user, "@bot: operable:role --grant --group=#{group.name} cheer") |> Map.fetch!("response")
    assert response == "Granted role `cheer` to group `elves`"
  end

  test "errors using the role command", %{user: user} do
    response = send_message(user, "@bot: operable:role --create ") |> Map.fetch!("response")
    assert response == "@belf Whoops! An error occurred. ERROR! Unable to create ``:\nMissing name"

    response = send_message(user, "@bot: operable:role --grant --user=belf") |> Map.fetch!("response")
    assert response == "@belf Whoops! An error occurred. ERROR! Must specify a role to modify."
  end

  test "dropping a role", %{user: user} do
    role("cheer")
    response = send_message(user, "@bot: operable:role --grant --user=belf cheer") |> Map.fetch!("response")
    assert response == "Granted role `cheer` to user `belf`"

    response = send_message(user, "@bot: operable:role --drop cheer") |> Map.fetch!("response")
    assert response == "@belf Whoops! An error occurred. ERROR! Unable to delete role `cheer`. There are assignments to this role: \n* user: belf\n"

    response = send_message(user, "@bot: operable:role --revoke --user=belf cheer") |> Map.fetch!("response")
    assert response == "Revoked role `cheer` from user `belf`"

    response = send_message(user, "@bot: operable:role --drop cheer") |> Map.fetch!("response")
    assert response == "The role `cheer` has been deleted."

    response = send_message(user, "@bot: operable:role --drop cheer") |> Map.fetch!("response")
    assert response == "@belf Whoops! An error occurred. ERROR! The role `cheer` does not exist."
  end

  test "revoking a role", %{user: user} do
    group("elves")
    role("cheer")

    response = send_message(user, "@bot: operable:role --grant --group=elves cheer") |> Map.fetch!("response")
    assert response == "Granted role `cheer` to group `elves`"

    response = send_message(user, "@bot: operable:role --revoke --group=elves cheer") |> Map.fetch!("response")
    assert response == "Revoked role `cheer` from group `elves`"
  end

  test "listing roles", %{user: user} do
    group("elves")
    role("cheer")

    response = send_message(user, "@bot: operable:role --grant --group=elves cheer") |> Map.fetch!("response")
    assert response == "Granted role `cheer` to group `elves`"

    response = send_message(user, "@bot: operable:role --grant --user=belf cheer") |> Map.fetch!("response")
    assert response == "Granted role `cheer` to user `belf`"

    response = send_message(user, "@bot: operable:role --list") |> Map.fetch!("response")
    assert response == "The following are the available roles: \n* cheer\n"

    response = send_message(user, "@bot: operable:role --drop cheer") |> Map.fetch!("response")
    assert response == "@belf Whoops! An error occurred. ERROR! Unable to delete role `cheer`. There are assignments to this role: \n* user: belf\n* group: elves\n"
  end
end

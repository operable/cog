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
    send_message user, "@bot: operable:role --grant --user=#{user.username} cheer"
    assert_response "@belf Whoops! An error occurred. ERROR! Could not find role `cheer`"

    send_message user, "@bot: operable:role --create cheer"
    assert_response "The role `cheer` has been created."

    send_message user, "@bot: operable:role --grant --user=papa_elf cheer"
    assert_response "@belf Whoops! An error occurred. ERROR! Could not find user `papa_elf`"

    send_message user, "@bot: operable:role --grant cheer"
    assert_response "@belf Whoops! An error occurred. ERROR! Must specify a target to act upon. See `operable:help operable:role` for more details."

    send_message user, "@bot: operable:role --grant --user=belf cheer"
    assert_response "Granted role `cheer` to user `belf`"
  end

  test "creating a role", %{user: user} do
    send_message user, "@bot: operable:role --create test"
    assert_response "The role `test` has been created."

    send_message user, "@bot: operable:role --create test"
    assert_response "@belf Whoops! An error occurred. ERROR! The role `test` already exists."
  end

  test "granting a role to a group", %{user: user} do
    group = group("elves")

    send_message user, "@bot: operable:role --grant --group=#{group.name} cheer"
    assert_response "@belf Whoops! An error occurred. ERROR! Could not find role `cheer`"

    send_message user, "@bot: operable:role --create cheer"
    assert_response "The role `cheer` has been created."

    send_message user, "@bot: operable:role --grant --group=humbug cheer"
    assert_response "@belf Whoops! An error occurred. ERROR! Could not find group `humbug`"

    send_message user, "@bot: operable:role --grant --group=#{group.name} cheer"
    assert_response "Granted role `cheer` to group `elves`"
  end

  test "errors using the role command", %{user: user} do
    send_message user, "@bot: operable:role --create "
    assert_response "@belf Whoops! An error occurred. ERROR! Unable to create ``:\nMissing name"

    send_message user, "@bot: operable:role --grant --user=belf"
    assert_response "@belf Whoops! An error occurred. ERROR! Must specify a role to modify."
  end

  test "dropping a role", %{user: user} do
    role("cheer")
    send_message user, "@bot: operable:role --grant --user=belf cheer"
    assert_response "Granted role `cheer` to user `belf`"

    send_message user, "@bot: operable:role --drop cheer"
    assert_response "@belf Whoops! An error occurred. ERROR! Unable to delete role `cheer`. There are assignments to this role: \n* user: belf\n"

    send_message user, "@bot: operable:role --revoke --user=belf cheer"
    assert_response "Revoked role `cheer` from user `belf`"

    send_message user, "@bot: operable:role --drop cheer"
    assert_response "The role `cheer` has been deleted."

    send_message user, "@bot: operable:role --drop cheer"
    assert_response "@belf Whoops! An error occurred. ERROR! The role `cheer` does not exist."
  end

  test "revoking a role", %{user: user} do
    group("elves")
    role("cheer")

    send_message user, "@bot: operable:role --grant --group=elves cheer"
    assert_response "Granted role `cheer` to group `elves`"

    send_message user, "@bot: operable:role --revoke --group=elves cheer"
    assert_response "Revoked role `cheer` from group `elves`"
  end

  test "listing roles", %{user: user} do
    group("elves")
    role("cheer")

    send_message user, "@bot: operable:role --grant --group=elves cheer"
    assert_response "Granted role `cheer` to group `elves`"

    send_message user, "@bot: operable:role --grant --user=belf cheer"
    assert_response "Granted role `cheer` to user `belf`"

    send_message user, "@bot: operable:role --list"
    assert_response "The following are the available roles: \n* cheer\n"

    send_message user, "@bot: operable:role --drop cheer"
    assert_response "@belf Whoops! An error occurred. ERROR! Unable to delete role `cheer`. There are assignments to this role: \n* user: belf\n* group: elves\n"
  end
end

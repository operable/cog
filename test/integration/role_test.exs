defmodule Integration.RoleTest do
  use Cog.AdapterCase, adapter: "test"

  setup do
    user = user("belf", first_name: "Buddy", last_name: "Elf")
    |> with_chat_handle_for("test")
    |> with_permission("operable:manage_groups")
    |> with_permission("operable:manage_roles")

    {:ok, %{user: user}}
  end

  test "creating a role", %{user: user} do
    response = send_message(user, "@bot: operable:role --create test")
    assert_payload(response, %{body: ["The role `test` has been created."]})

    response = send_message(user, "@bot: operable:role --create test")
    assert_error_message_contains(response, "Whoops! An error occurred. ERROR! The role `test` already exists.")
  end

  test "granting a role to a group", %{user: user} do
    group = group("elves")

    response = send_message(user, "@bot: operable:role --grant --group=#{group.name} cheer")
    assert_error_message_contains(response, "Whoops! An error occurred. ERROR! Could not find role `cheer`")

    response = send_message(user, "@bot: operable:role --create cheer")
    assert_payload(response, %{body: ["The role `cheer` has been created."]})

    response = send_message(user, "@bot: operable:role --grant --group=humbug cheer")
    assert_error_message_contains(response, "Whoops! An error occurred. ERROR! Could not find group `humbug`")

    response = send_message(user, "@bot: operable:role --grant --group=#{group.name} cheer")
    assert_payload(response, %{body: ["Granted role `cheer` to group `elves`"]})
  end

  test "errors using the role command", %{user: user} do
    response = send_message(user, "@bot: operable:role --create ")
    assert_error_message_contains(response, "Whoops! An error occurred. ERROR! Unable to create ``:\nMissing name")

    response = send_message(user, "@bot: operable:role --grant --user=belf")
    assert_error_message_contains(response, "Whoops! An error occurred. ERROR! Must specify a role to modify.")
  end

  test "dropping a role", %{user: user} do
    role("cheer")
    group("test-group")

    response = send_message(user, "@bot: operable:role --grant --group=test-group cheer")
    assert_payload(response, %{body: ["Granted role `cheer` to group `test-group`"]})

    response = send_message(user, "@bot: operable:role --drop cheer")
    assert_error_message_contains(response, "Whoops! An error occurred. ERROR! Unable to delete role `cheer`. There are assignments to this role: \n* group: test-group\n")

    response = send_message(user, "@bot: operable:role --revoke --group=test-group cheer")
    assert_payload(response, %{body: ["Revoked role `cheer` from group `test-group`"]})

    response = send_message(user, "@bot: operable:role --drop cheer")
    assert_payload(response, %{body: ["The role `cheer` has been deleted."]})

    response = send_message(user, "@bot: operable:role --drop cheer")
    assert_error_message_contains(response, "Whoops! An error occurred. ERROR! The role `cheer` does not exist.")
  end

  test "revoking a role", %{user: user} do
    group("elves")
    role("cheer")

    response = send_message(user, "@bot: operable:role --grant --group=elves cheer")
    assert_payload(response, %{body: ["Granted role `cheer` to group `elves`"]})

    response = send_message(user, "@bot: operable:role --revoke --group=elves cheer")
    assert_payload(response, %{body: ["Revoked role `cheer` from group `elves`"]})
  end

  test "listing roles", %{user: user} do
    role("cheer")
    role("happy")

    response = send_message(user, "@bot: operable:role --list")
    assert_payload(response, %{body: ["The following are the available roles: \n* happy\n* cheer\n"]})
  end
end

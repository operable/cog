defmodule Integration.PermissionTest do
  use Cog.AdapterCase, adapter: Cog.Adapters.Test

  setup do
    user = user("vanstee", first_name: "Patrick", last_name: "Van Stee")
    |> with_chat_handle_for("Test")
    |> with_permission("operable:manage_users")
    |> with_permission("operable:manage_groups")
    |> with_permission("operable:manage_roles")

    group = group("ops")
    :ok = Groupable.add_to(user, group)

    role = role("admin")
    :ok = Permittable.grant_to(user, role)

    {:ok, %{user: user, group: group, role: role}}
  end

  test "granting a permission to a user", %{user: user} do
    send_message user, "@bot: operable:st-echo test"
    assert_response "@vanstee Sorry, you aren't allowed to execute 'operable:st-echo test' :(\n You will need the 'operable:st-echo' permission to run this command."

    send_message user, "@bot: operable:permissions --grant --user=vanstee --permission=operable:st-echo"
    assert_response "Granted permission `operable:st-echo` to user `vanstee`"

    send_message user, "@bot: operable:st-echo test"
    assert_response "test"
  end

  test "granting a permission to a group", %{user: user} do
    send_message user, "@bot: operable:st-echo test"
    assert_response "@vanstee Sorry, you aren't allowed to execute 'operable:st-echo test' :(\n You will need the 'operable:st-echo' permission to run this command."

    send_message user, "@bot: operable:permissions --grant --group=ops --permission=operable:st-echo"
    assert_response "Granted permission `operable:st-echo` to group `ops`"

    send_message user, "@bot: operable:st-echo test"
    assert_response "test"
  end

  test "granting a permission to a role", %{user: user} do
    send_message user, "@bot: operable:st-echo test"
    assert_response "@vanstee Sorry, you aren't allowed to execute 'operable:st-echo test' :(\n You will need the 'operable:st-echo' permission to run this command."

    send_message user, "@bot: operable:permissions --grant --role=admin --permission=operable:st-echo"
    assert_response "Granted permission `operable:st-echo` to role `admin`"

    send_message user, "@bot: operable:st-echo test"
    assert_response "test"
  end

  test "granting a permission to a user without the grant permission" do
    mctesterson = user("mctesterson", first_name: "Testy", last_name: "McTesterson")
    |> with_chat_handle_for("Test")

    send_message mctesterson, "@bot: operable:permissions --grant --user=mctesterson --permission=operable:st-echo"
    assert_response "@mctesterson Sorry, you aren't allowed to execute 'operable:permissions --grant --user=mctesterson --permission=operable:st-echo' :(\n You will need the 'operable:manage_users' permission to run this command."
  end

  test "revoking a permission from a user", %{user: user} do
    send_message user, "@bot: operable:permissions --grant --user=vanstee --permission=operable:st-echo"
    assert_response "Granted permission `operable:st-echo` to user `vanstee`"

    send_message user, "@bot: operable:st-echo test"
    assert_response "test"

    send_message user, "@bot: operable:permissions --revoke --user=vanstee --permission=operable:st-echo"
    assert_response "Revoked permission `operable:st-echo` from user `vanstee`"

    send_message user, "@bot: operable:st-echo test"
    assert_response "@vanstee Sorry, you aren't allowed to execute 'operable:st-echo test' :(\n You will need the 'operable:st-echo' permission to run this command."
  end

  test "revoking a permission from a group", %{user: user} do
    send_message user, "@bot: operable:permissions --grant --group=ops --permission=operable:st-echo"
    assert_response "Granted permission `operable:st-echo` to group `ops`"

    send_message user, "@bot: operable:st-echo test"
    assert_response "test"

    send_message user, "@bot: operable:permissions --revoke --group=ops --permission=operable:st-echo"
    assert_response "Revoked permission `operable:st-echo` from group `ops`"

    send_message user, "@bot: operable:st-echo test"
    assert_response "@vanstee Sorry, you aren't allowed to execute 'operable:st-echo test' :(\n You will need the 'operable:st-echo' permission to run this command."
  end

  test "revoking a permission from a role", %{user: user} do
    send_message user, "@bot: operable:permissions --grant --role=admin --permission=operable:st-echo"
    assert_response "Granted permission `operable:st-echo` to role `admin`"

    send_message user, "@bot: operable:st-echo test"
    assert_response "test"

    send_message user, "@bot: operable:permissions --revoke --role=admin --permission=operable:st-echo"
    assert_response "Revoked permission `operable:st-echo` from role `admin`"

    send_message user, "@bot: operable:st-echo test"
    assert_response "@vanstee Sorry, you aren't allowed to execute 'operable:st-echo test' :(\n You will need the 'operable:st-echo' permission to run this command."
  end
end

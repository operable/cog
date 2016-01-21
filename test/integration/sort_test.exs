defmodule Integration.SortTest do
  use Cog.AdapterCase, adapter: Cog.Adapters.Test
  import DatabaseTestSetup

  setup do
    user = user("jfrost", first_name: "Jim", last_name: "Frost")
    |> with_chat_handle_for("Test")
    |> with_permission("operable:manage_commands")

    {:ok, %{user: user}}
  end

  test "sorting numbers", %{user: user} do
    send_message user, "@bot: operable:sort 7 3 6 4 5 9"
    assert_response "3\n4\n5\n6\n7\n9"

    send_message user, "@bot: operable:sort -desc 7 3 6 4 5 9"
    assert_response "9\n7\n6\n5\n4\n3"

    send_message user, "@bot: operable:sort --asc 7 3 6 4 5 9"
    assert_response "3\n4\n5\n6\n7\n9"
  end

  test "sorting strings", %{user: user} do
    send_message user, "@bot: operable:sort --desc Life goes on"
    assert_response "on\ngoes\nLife"

    send_message user, "@bot: operable:sort Life is 10 percent what happens to us and 90% how we react to it"
    assert_response "10\n90\n%\nLife\nand\nhappens\nhow\nis\nit\npercent\nreact\nto\nto\nus\nwe\nwhat"
  end

  #@tag :skip
  test "sorting in a pipeline", %{user: user} do
    rule("when command is operable:rules with option[user] == /.*/ must have operable:manage_users")
    rule("when command is operable:rules with option[role] == /.*/ must have operable:manage_roles")
    rule("when command is operable:rules with option[group] == /.*/ must have operable:manage_groups")

    send_message user, "@bot: operable:rules --list --for-command=operable:rules | sort --field=rule"
    response = get_response
    assert length(response) == 3
    [first | remaining] = response
    assert first["rule"] == "when command is operable:rules with option[user] == /.*/ must have operable:manage_users"
    [second | [third]] = remaining
    assert second["rule"] == "when command is operable:rules with option[role] == /.*/ must have operable:manage_roles"
    assert third["rule"] == "when command is operable:rules with option[group] == /.*/ must have operable:manage_groups"
  end

end

defmodule Integration.SortTest do
  use Cog.AdapterCase, adapter: "test"
  import DatabaseTestSetup

  setup do
    user = user("jfrost", first_name: "Jim", last_name: "Frost")
    |> with_chat_handle_for("test")
    |> with_permission("operable:manage_commands")

    {:ok, %{user: user}}
  end

  test "sorting numbers", %{user: user} do
    response = send_message(user, "@bot: operable:sort 7 3 6 4 5 9")
    assert response["data"]["response"] == "3\n4\n5\n6\n7\n9"

    response = send_message(user, "@bot: operable:sort -desc 7 3 6 4 5 9")
    assert response["data"]["response"] == "9\n7\n6\n5\n4\n3"

    response = send_message(user, "@bot: operable:sort --asc 7 3 6 4 5 9")
    assert response["data"]["response"] == "3\n4\n5\n6\n7\n9"
  end

  test "sorting strings", %{user: user} do
    response = send_message(user, "@bot: operable:sort --desc Life goes on")
    assert response["data"]["response"] == "on\ngoes\nLife"

    response = send_message(user, "@bot: operable:sort Life is 10 percent what happens to us and 90% how we react to it")
    assert response["data"]["response"] == "10\n90%\nLife\nand\nhappens\nhow\nis\nit\npercent\nreact\nto\nto\nus\nwe\nwhat"
  end

  test "sorting in a pipeline", %{user: user} do
    rule("when command is operable:rules with option[user] == /.*/ must have operable:manage_users")
    rule("when command is operable:rules with option[role] == /.*/ must have operable:manage_roles")
    rule("when command is operable:rules with option[group] == /.*/ must have operable:manage_groups")

    response = send_message(user, "@bot: operable:rules --list --for-command=operable:rules | sort --field=rule")
    response = response["data"]["response"]

    assert response =~ """
    {
      \"rule\": \"when command is operable:rules must have operable:manage_commands\",
      \"id\": \".*\",
      \"command\": \"operable:rules\"
    }
    {
      \"rule\": \"when command is operable:rules with option\\[group\\] == /.*/ must have operable:manage_groups\",
      \"id\": \".*\",
      \"command\": \"operable:rules\"
    }
    {
      \"rule\": \"when command is operable:rules with option\\[role\\] == /.*/ must have operable:manage_roles\",
      \"id\": \".*\",
      \"command\": \"operable:rules\"
    }
    {
      \"rule\": \"when command is operable:rules with option\\[user\\] == /.*/ must have operable:manage_users\",
      \"id\": \".*\",
      \"command\": \"operable:rules\"
    }
    """ |> String.rstrip |> Regex.compile!
  end
end

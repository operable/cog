defmodule Integration.AliasExecutionTest do
  use Cog.AdapterCase, adapter: "test"

  setup do
    user = user("vanstee", first_name: "Patrick", last_name: "Van Stee")
    |> with_chat_handle_for("test")

    {:ok, %{user: user}}
  end

  test "alias executes properly", %{user: user} do
    send_message(user, "@bot: operable:alias create my-alias \"echo my alias\"")

    response = send_message(user, "@bot: my-alias")

    assert response == "my alias"
  end

  test "alias executes properly in the site namespace", %{user: user} do
    send_message(user, "@bot: operable:alias create my-alias \"echo my alias\"")
    send_message(user, "@bot: operable:alias move my-alias site")

    response = send_message(user, "@bot: my-alias")

    assert response == "my alias"
  end

  test "alias executes properly in pipelines", %{user: user} do
    send_message(user, "@bot: operable:alias create my-alias \"echo my alias\"")

    response = send_message(user, "@bot: my-alias | echo $body[0]")

    assert response == "my alias"
  end

  test "alias executes properly in mid pipeline", %{user: user} do
    send_message(user, "@bot: operable:alias create my-alias \"echo $body[0]\"")

    response = send_message(user, "@bot: echo \"foo\" | my-alias")

    assert response == "foo"
  end

  test "alias nested expansion works properly", %{user: user} do
    send_message(user, "@bot: operable:alias create my-alias \"echo my alias\"")
    send_message(user, "@bot: operable:alias create my-other-alias \"my-alias\"")

    response = send_message(user, "@bot: my-other-alias")

    assert response == "my alias"
  end

  test "alias expansion fails on infinite expansion", %{user: user} do
    send_message(user, "@bot: operable:alias create my-alias \"my-alias\"")

    response = send_message(user, "@bot: my-alias")

    assert_error_message_contains(response, "An error occurred. Alias expansion limit (5) exceeded starting with alias 'my-alias'.")
  end

  test "alias using slack emoji works", %{user: user} do
    send_message(user, "@bot: alias create \":boom:\" \"echo BOOM\"")

    response = send_message(user, "@bot: :boom:")

    assert response == "BOOM"
  end

end

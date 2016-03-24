defmodule Integration.AliasExecutionTest do
  use Cog.AdapterCase, adapter: "test"

  setup do
    user = user("vanstee", first_name: "Patrick", last_name: "Van Stee")
    |> with_chat_handle_for("test")

    {:ok, %{user: user}}
  end

  test "alias executes properly", %{user: user} do
    send_message(user, "@bot: operable:alias new my-alias \"echo my alias\"")
    response = send_message(user, "@bot: my-alias") |> Map.fetch!("response")

    assert response == "my alias"
  end

  test "alias executes properly in the site namespace", %{user: user} do
    send_message(user, "@bot: operable:alias new my-alias \"echo my alias\"")
    send_message(user, "@bot: operable:alias mv my-alias site")
    response = send_message(user, "@bot: my-alias") |> Map.fetch!("response")

    assert response == "my alias"
  end

  test "alias executes properly in pipelines", %{user: user} do
    send_message(user, "@bot: operable:alias new my-alias \"echo my alias\"")
    response = send_message(user, "@bot: my-alias | echo $body") |> Map.fetch!("response")

    assert response == "my alias"
  end

  test "alias executes properly in mid pipeline", %{user: user} do
    send_message(user, "@bot: operable:alias new my-alias \"echo $body\"")
    response = send_message(user, "@bot: echo \"foo\" | my-alias") |> Map.fetch!("response")

    assert response == "foo"
  end

  test "alias nested expansion works properly", %{user: user} do
    send_message(user, "@bot: operable:alias new my-alias \"echo my alias\"")
    send_message(user, "@bot: operable:alias new my-other-alias \"my-alias\"")
    response = send_message(user, "@bot: my-other-alias") |> Map.fetch!("response")

    assert response == "my alias"
  end

  test "alias expansion fails on infinite expansion", %{user: user} do
    send_message(user, "@bot: operable:alias new my-alias \"my-alias\"")
    response = send_message(user, "@bot: my-alias") |> Map.fetch!("response")
    assert "@vanstee Alias expansion limit (5) exceeded starting with alias 'my-alias'." = response
  end

  test "alias using slack emoji works", %{user: user} do
    send_message(user, "@bot: alias new \":boom:\" \"echo BOOM\"")
    response = send_message(user, "@bot: :boom:") |> Map.fetch!("response")
    assert Regex.match?(~r/BOOM/, response)
  end

end

defmodule Integration.SlackTest do
  use Cog.AdapterCase, adapter: "slack"

  @moduletag :slack

  setup do
    user = user("botci")
    |> with_chat_handle_for("slack")

    {:ok, %{user: user}}
  end

  test "editing a command", %{user: user} do
    user |> with_permission("operable:st-echo")

    message = send_edited_message(user, "@deckard: operable:st-echo test")
    assert_edited_response "@botci Executing edited command 'operable:st-echo test'\ntest", after: message
  end

  test "running the st-echo command", %{user: user} do
    user |> with_permission("operable:st-echo")

    message = send_message user, "@deckard: operable:st-echo test"
    assert_response "test", after: message
  end

  test "running the st-echo command without permission", %{user: user} do
    message = send_message user, "@deckard: operable:st-echo test"
    assert_response "@botci Sorry, you aren't allowed to execute 'operable:st-echo test' :(\n You will need the 'operable:st-echo' permission to run this command.", after: message
  end

  test "running commands in a pipeline", %{user: user} do
    user
    |> with_permission("operable:echo")
    |> with_permission("operable:thorn")

    message = send_message user, ~s(@deckard: operable:echo "this is a test" | operable:thorn $body)
    assert_response "þis is a test", after: message
  end

  test "running commands in a pipeline without permission", %{user: user} do
    user |> with_permission("operable:st-echo")

    message = send_message user, ~s(@deckard: operable:st-echo "this is a test" | operable:st-thorn $body)
    assert_response "@botci Sorry, you aren't allowed to execute 'operable:st-thorn $body' :(\n You will need the 'operable:st-thorn' permission to run this command.", after: message
  end
end

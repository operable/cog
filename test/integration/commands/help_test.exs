defmodule Integration.Commands.HelpTest do
  use Cog.AdapterCase, adapter: "test"
  alias Cog.Support.ModelUtilities

  setup do
    user = user("vanstee", first_name: "Patrick", last_name: "Van Stee")
    |> with_chat_handle_for("test")

    {:ok, %{user: user}}
  end

  test "listing bundles", %{user: user} do
    ModelUtilities.command("test-command")

    response = send_message(user, "@bot: operable:help")

    assert String.contains?(response, "operable")
    assert String.contains?(response, "test-bundle")
  end

  test "showing docs for a command", %{user: user} do
    ModelUtilities.command("test-command", %{description: "Does test command things", arguments: "[test-arg]"})

    response = send_message(user, "@bot: operable:help test-bundle:test-command")

    assert String.contains?(response, "Does test command things")
    assert String.contains?(response, "test-bundle:test-command [test-arg]")
  end
end

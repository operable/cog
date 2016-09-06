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

    [%{body: body}] = send_message(user, "@bot: operable:help")

    assert String.contains?(body, "operable")
    assert String.contains?(body, "test-bundle")
  end

  test "showing docs for a command", %{user: user} do
    ModelUtilities.command("test-command", %{description: "Does test command things", arguments: "[test-arg]"})

    [%{body: body}] = send_message(user, "@bot: operable:help test-bundle:test-command")

    assert String.contains?(body, "Does test command things")
    assert String.contains?(body, "test-bundle:test-command [test-arg]")
  end
end

defmodule Integration.Commands.HelpTest do
  use Cog.AdapterCase, adapter: "test"
  alias Cog.Support.ModelUtilities

  setup do
    user = user("vanstee", first_name: "Patrick", last_name: "Van Stee")
    |> with_chat_handle_for("test")

    {:ok, %{user: user}}
  end

  test "listing enabled commands", %{user: user} do
    commands = send_message(user, "@bot: operable:help")

    # We should only have the operable bundle installed at this point
    assert Enum.all?(commands, fn command ->
      command.bundle.name == "operable"
    end)
  end

  test "list disabled commands", %{user: user} do
    ModelUtilities.command("test_command")

    [command] = send_message(user, "@bot: operable:help --disabled")

    assert command.bundle.name == "test-bundle"
    assert command.name == "test_command"
  end

  test "list enabled commands when there are also disabled commands", %{user: user} do
    ModelUtilities.command("test_command")

    commands = send_message(user, "@bot: operable:help")

    # All enabled commands should be in the operable bundle
    assert Enum.all?(commands, fn command ->
      command.bundle.name == "operable"
    end)
  end
end

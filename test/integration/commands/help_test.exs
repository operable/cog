defmodule Integration.Commands.HelpTest do
  use Cog.AdapterCase, adapter: "test"
  alias Cog.Support.ModelUtilities

  @moduletag :skip

  setup do
    user = user("vanstee", first_name: "Patrick", last_name: "Van Stee")
    |> with_chat_handle_for("test")

    {:ok, %{user: user}}
  end

  test "listing enabled commands", %{user: user} do
    response = send_message(user, "@bot: operable:help")
    commands = decode_payload(response)

    # We should only have the operable bundle installed at this point
    assert Enum.all?(commands, fn command ->
      command.bundle.name == "operable"
    end)
  end

  test "list disabled commands", %{user: user} do
    ModelUtilities.command("test_command")

    response = send_message(user, "@bot: operable:help --disabled")
    [command] = decode_payload(response)

    assert command.bundle.name == "cog"
    assert command.name == "test_command"
  end

  test "list enabled commands when there are also disabled commands", %{user: user} do
    ModelUtilities.command("test_command")

    response = send_message(user, "@bot: operable:help")
    commands = decode_payload(response)

    # All enabled commands should be in the operable bundle
    assert Enum.all?(commands, fn command ->
      command.bundle.name == "operable"
    end)
  end

  test "list all commands", %{user: user} do
    ModelUtilities.command("test_command")

    response = send_message(user, "@bot: operable:help --all")
    commands = decode_payload(response)

    # Now we should have some commands that start with operable and some with cog
    assert Enum.any?(commands, fn command ->
      command.bundle.name == "operable"
    end)

    assert Enum.any?(commands, fn command ->
      command.bundle.name == "cog"
    end)
  end
end

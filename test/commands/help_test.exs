defmodule Cog.Test.Commands.HelpTest do
  use Cog.CommandCase, command_module: Cog.Commands.Help

  test "listing bundles" do
    ModelUtilities.command("test-command")

    request = new_req()
    {:ok, response} = send_req(request)

    decoded = Poison.decode!(response)
    assert %{"enabled" => [%{"name" => "operable"}],
             "disabled" => [%{"name" => "test-bundle"}]} = decoded
  end

  test "showing docs for a command" do
    ModelUtilities.command("test-command", %{description: "Does test command things", arguments: "[test-arg]"})

    request = new_req(args: ["test-bundle:test-command"])
    {:ok, response} = send_req(request)

    decoded = Poison.decode!(response)
    assert %{"name" => "test-command",
             "description" => "Does test command things"} = decoded
  end
end

defmodule Cog.Test.Commands.HelpTest do
  use Cog.CommandCase, command_module: Cog.Commands.Help

  alias Cog.Support.ModelUtilities

  test "listing bundles" do
    ModelUtilities.command("test-command")

    request = new_req()
    {:ok, response} = send_req(request)

    assert %{enabled: [%{name: "operable"}],
             disabled: [%{name: "test-bundle"}]} = response
  end

  test "showing docs for a command" do
    ModelUtilities.command("test-command", %{description: "Does test command things", arguments: "[test-arg]"})

    request = new_req(args: ["test-bundle:test-command"])
    {:ok, response} = send_req(request)

    assert %{name: "test-command",
             description: "Does test command things"} = response
  end
end

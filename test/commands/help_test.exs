defmodule Cog.Test.Commands.HelpTest do
  use Cog.CommandCase, command_module: Cog.Commands.Help

  import Cog.Support.ModelUtilities, only: [command: 2,
                                            bundle_version: 1]

  describe "general help" do

    setup :with_command

    test "listing bundles" do
      response = new_req()
                 |> send_req()
                 |> unwrap()

      assert %{enabled: [%{name: "operable"}],
               disabled: [%{name: "test-bundle"}]} = response
    end

    test "showing docs for a command" do
      response = new_req(args: ["test-bundle:test-command"])
                 |> send_req()
                 |> unwrap()

      assert %{name: "test-command",
               description: "Does test command things"} = response
    end

    test "showing docs for a command using the git style syntax" do
      response = new_req(args: ["test", "command"])
                 |> send_req()
                 |> unwrap()

      assert %{name: "test-command",
               description: "Does test command things"} = response
    end

    test "showing docs for a bundle" do
      response = new_req(args: ["test-bundle"])
                 |> send_req()
                 |> unwrap()

      assert(%{name: "test-bundle"} = response)
    end

    test "shows an error when a command does not exist" do
      error = new_req(args: ["test-bundle:does-not-exist"])
              |> send_req()
              |> unwrap_error()

      error_msg = "Command 'test-bundle:does-not-exist' not found. Check the bundle and command name and try again." 

      assert(error_msg == error)
    end

  end

  describe "non-fully qualified commands" do

    setup :with_command

    test "showing docs for a command" do
      response = new_req(args: ["test-command"])
                 |> send_req()
                 |> unwrap()

      assert(%{name: "test-command",
               description: "Does test command things"} = response)
    end

    test "shows bundle docs when a command and bundle name are ambiguous" do
      bundle_version("test-ambiguous")

      response = new_req(args: ["test-ambiguous"])
                 |> send_req()
                 |> unwrap()
                 |> Map.get(:config_file)

      # The existance of the 'cog_bundle_version' key denotes this as a bundle version.
      assert(%{cog_bundle_version: _,
               name: "test-ambiguous"} = response)
    end

    test "shows an error when a bundle or comamnd isn't found" do
      error = new_req(args: ["does-not-exist"])
              |> send_req()
              |> unwrap_error()

      assert(error == "Could not find a bundle or a command in any bundle with the name 'does-not-exist'. Check the name and try again.")
    end

    test "shows an error when a command is ambiguous" do
      command("test-command",
              %{bundle_name: "other-test-bundle",
                description: "Does test command things", arguments: "[test-arg]"})

      error = new_req(args: ["test-command"])
              |> send_req()
              |> unwrap_error()

      error_msg = """
      Multiple bundles contain a command with the name 'test-command'.
      Please specify which command by using the command's fully qualified name.

      other-test-bundle:test-command
      test-bundle:test-command
      """

      assert(error_msg == error)
    end

  end

  describe "git style syntax" do

    setup :with_command

    test "fully qualified command" do
      response = new_req(args: ["test-bundle:test", "command"])
                 |> send_req()
                 |> unwrap()

      assert %{name: "test-command",
               description: "Does test command things"} = response
    end

    test "just the command" do
      response = new_req(args: ["test", "command"])
                 |> send_req()
                 |> unwrap()

      assert %{name: "test-command",
               description: "Does test command things"} = response
    end

    test "shows an error for ambiguous commands" do
      command("test-command",
              %{bundle_name: "other-test-bundle",
                description: "Does test command things", arguments: "[test-arg]"})

      error = new_req(args: ["test", "command"])
              |> send_req()
              |> unwrap_error()

      error_msg = """
      Multiple bundles contain a command with the name 'test-command'.
      Please specify which command by using the command's fully qualified name.

      other-test-bundle:test-command
      test-bundle:test-command
      """

      assert(error_msg == error)
    end

    test "shows an error when the bundle name has a space in fully qualified names" do
      error = new_req(args: ["test", "bundle:test", "command"])
            |> send_req()
            |> unwrap_error()

      assert(error == "Invalid bundle name 'test bundle'. Check the name and try again.")
    end

    test "shows an error when a command cannot be found" do
      error = new_req(args: ["does", "not", "exist"])
              |> send_req()
              |> unwrap_error()

      assert(error == "Could not find a command in any bundle with the name 'does-not-exist'. Check the name and try again.")
    end

  end

  #### Setup Functions ####

  defp with_command(_) do
    [command: command("test-command",
                      %{bundle_name: "test-bundle",
                        description: "Does test command things",
                        arguments: "[test-arg]"})]
  end
end

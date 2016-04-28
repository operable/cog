defmodule Cog.Bundle.Config.Test do
  use ExUnit.Case, async: true
  alias Cog.Bundle.Config
  alias Cog.Command.GenCommand

  # Create some test modules; these will be our "bundle"

  defmodule CommandWithoutOptions do
    use GenCommand.Base, name: "command-without-options", bundle: "testing"

    permission "foo"
    rule "when command is testing:command-without-options must have testing:foo"
    def handle_message(_,_), do: {:reply, "blah", "blah", :blah}
  end

  defmodule CommandWithOptions do
    use GenCommand.Base, name: "command-with-options", bundle: "testing"

    option "option_1", type: "bool", required: true
    permission "bar"
    permission "baz"

    rule "when command is testing:command-with-options must have testing:bar"
    rule "when command is testing:command-with-options with arg[0] == 'baz' must have testing:baz"
    def handle_message(_,_), do: {:reply, "blah", "blah", :blah}
  end

  defmodule UnenforcedCommand do
    use GenCommand.Base, name: "unenforced-command", enforcing: false, bundle: "testing"

    def handle_message(_,_), do: {:reply, "blah", "blah", "blah"}
  end

  defmodule UnboundCommand do
    use GenCommand.Base, name: "unbound-command", enforcing: false, bundle: "testing"

    def handle_message(_,_), do: {:reply, "blah", "blah", "blah"}
  end

  defmodule ExecutionOnceCommand do
    use GenCommand.Base, name: "execution-once-command", enforcing: false, bundle: "testing", execution: :once

    def handle_message(_,_), do: {:reply, "blah", "blah", "blah"}
  end

  defmodule NeitherCommandNorService do
    def howdy, do: "Hello World"
  end

  test "creates a config for a set of modules" do
    config = Config.gen_config("testing", [CommandWithoutOptions,
                                           CommandWithOptions,
                                           UnenforcedCommand,
                                           UnboundCommand,
                                           ExecutionOnceCommand,
                                           NeitherCommandNorService], ".")
    assert %{"name" => "testing",
             "type" => "elixir",
             "version" => "0.0.1",
             "commands" => %{
               "command-without-options" => %{
                 "documentation" => nil,
                 "enforcing" => true,
                 "execution" => "multiple",
                 "module" => "Cog.Bundle.Config.Test.CommandWithoutOptions",
                 "rules" => [
                   "when command is testing:command-without-options must have testing:foo"
                 ]},
               "command-with-options" => %{
                 "documentation" => nil,
                 "enforcing" => true,
                 "execution" => "multiple",
                 "module" => "Cog.Bundle.Config.Test.CommandWithOptions",
                 "options" => %{
                   "option_1" => %{
                     "type" => "bool",
                     "required" => true
                   }
                 },
                 "rules" => [
                   "when command is testing:command-with-options must have testing:bar",
                   "when command is testing:command-with-options with arg[0] == 'baz' must have testing:baz"
                 ]},
               "unenforced-command" => %{
                 "documentation" => nil,
                 "enforcing" => false,
                 "execution" => "multiple",
                 "module" => "Cog.Bundle.Config.Test.UnenforcedCommand"},
               "unbound-command" => %{
                 "documentation" => nil,
                 "enforcing" => false,
                 "execution" => "multiple",
                 "module" => "Cog.Bundle.Config.Test.UnboundCommand"},
               "execution-once-command" => %{
                 "documentation" => nil,
                 "enforcing" => false,
                 "execution" => "once",
                 "module" => "Cog.Bundle.Config.Test.ExecutionOnceCommand"}
             },
             "permissions" => ["testing:bar", "testing:baz", "testing:foo"]} = config
  end

  # TODO: Should this be allowed?
  test "creates a config when there are no commands, services, permissions, or rules" do
    config = Config.gen_config("testing", [NeitherCommandNorService], ".")

    assert %{"name" => "testing",
             "type" => "elixir",
             "version" => "0.0.1",
             "commands" => %{},
             "permissions" => [],
             "templates" => %{}} == config
  end

  @config %{"commands" => [%{"module" => "Elixir.AWS.Commands.Describe"},
                           %{"module" => "Elixir.AWS.Commands.Tag"}]}

  test "finding command beam files from manifest" do
    assert [
      {AWS.Commands.Describe, []},
      {AWS.Commands.Tag, []}
    ] = Config.commands(@config)
  end

  test "includes templates in the config" do
    config = Config.gen_config("testing", [], "test/support/test-bundle")

    assert %{"templates" => %{"help" => %{
                                "hipchat" => "{{#command}}\n  Documentation for <pre>{{command}}</pre>\n  {{{documentation}}}\n{{/command}}\n",
                                "slack" => "{{#command}}\n  Documentation for `{{command}}`\n  {{{documentation}}}\n{{/command}}\n"
                              }}} = config
  end
end

defmodule Cog.Bundle.Config.Test do
  use ExUnit.Case, async: true
  alias Cog.Bundle.Config
  alias Cog.Command.GenCommand

  # Create some test modules; these will be our "bundle"

  defmodule CommandWithoutOptions do
    use GenCommand.Base, name: "command-without-options", bundle: "testing"
    @description "description"
    permission "foo"
    rule "when command is testing:command-without-options must have testing:foo"
    def handle_message(_,_), do: {:reply, "blah", "blah", :blah}
  end

  defmodule CommandWithOptions do
    use GenCommand.Base, name: "command-with-options", bundle: "testing"
    @description "description"
    option "option_1", type: "bool", required: true
    permission "bar"
    permission "baz"

    rule "when command is testing:command-with-options must have testing:bar"
    rule "when command is testing:command-with-options with arg[0] == 'baz' must have testing:baz"
    def handle_message(_,_), do: {:reply, "blah", "blah", :blah}
  end

  defmodule NeitherCommandNorService do
    def howdy, do: "Hello World"
  end

  test "creates a config for a set of modules" do
    config = Config.gen_config("testing", "test all the things", "0.0.1", [CommandWithoutOptions,
                                                    CommandWithOptions,
                                                    NeitherCommandNorService], ".")
    assert %{"name" => "testing",
             "description" => "test all the things",
             "type" => "elixir",
             "version" => "0.0.1",
             "commands" => %{
               "command-without-options" => %{
                 "documentation" => nil,
                 "module" => "Cog.Bundle.Config.Test.CommandWithoutOptions",
                 "rules" => [
                   "when command is testing:command-without-options must have testing:foo"
                 ]},
               "command-with-options" => %{
                 "documentation" => nil,
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
             },
             "permissions" => ["testing:bar", "testing:baz", "testing:foo"]} = config
  end

  # TODO: Should this be allowed?
  test "creates a config when there are no commands, services, permissions, or rules" do
    config = Config.gen_config("testing", "test all the things", "1.0.0", [NeitherCommandNorService], ".")

    assert %{"name" => "testing",
             "description" => "test all the things",
             "type" => "elixir",
             "version" => "1.0.0",
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
    config = Config.gen_config("testing", "test all the things", "2.0.0", [], "test/support/test-bundle/templates")

    assert %{"templates" => %{"help" => %{
                                "slack" => "{{#command}}\n  Documentation for `{{command}}`\n  {{{documentation}}}\n{{/command}}\n"
                              }}} = config
  end
end

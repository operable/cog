defmodule Cog.Command.GenCommand.Base.Test do
  use ExUnit.Case

  alias Cog.Command.GenCommand
  alias Cog.Command.GenCommand.ValidationError

  defmodule TestCommand do
    use GenCommand.Base, bundle: "foo"
    @description "description"
    def handle_message(_,_), do: {:reply, "blah", "blah", :blah}
  end

  defmodule NotACommand do
    def howdy, do: "Hello World"
  end

  defmodule CommandWithOption do
    use GenCommand.Base, bundle: "foo"
    @description "description"
    option "my_option", type: "string", required: true
    def handle_message(_,_), do: {:reply, "blah", "blah", :blah}
  end

  defmodule CommandWithDefaultOption do
    use GenCommand.Base, bundle: "foo"
    @description "description"
    option "default_option"
    def handle_message(_,_), do: {:reply, "blah", "blah", :blah}
  end

  defmodule CommandWithMultipleOptions do
    use GenCommand.Base, bundle: "foo"
    @description "description"

    option "my_option", type: "string", required: true, description: "my description"
    option "another_option", type: "boolean", description: "another description"
    option "foooooo", short: "f"

    def handle_message(_,_), do: {:reply, "blah", "blah", :blah}
  end

  defmodule CommandWithPermission do
    use GenCommand.Base, bundle: "foo"
    @description "description"
    permission "foo"
    def handle_message(_,_), do: {:reply, "blah", "blah", :blah}
  end

  defmodule CommandWithMultiplePermissions do
    use GenCommand.Base, bundle: "foo"
    @description "description"
    permission "foo"
    permission "bar"
    permission "baz"
    def handle_message(_,_), do: {:reply, "blah", "blah", :blah}
  end

  defmodule CommandWithMultiplePermissionsDeclaredAtOnce do
    use GenCommand.Base, bundle: "foo"
    @description "description"
    permission ["one", "two", "three"]
    def handle_message(_,_), do: {:reply, "blah", "blah", :blah}
  end

  defmodule CommandWithMixOfPermissions do
    use GenCommand.Base, bundle: "foo"
    @description "description"
    permission "a"
    permission ["b", "c"]
    def handle_message(_,_), do: {:reply, "blah", "blah", :blah}
  end

  defmodule CommandWithRules do
    use GenCommand.Base, bundle: "foo", name: "command-with-rules"
    @description "description"
    permission "blah"
    rule "when command is foo:command-with-rules must have foo:blah"
    def handle_message(_,_), do: {:reply, "blah", "blah", :blah}
  end

  defmodule CommandWithMultipleRules do
    use GenCommand.Base, bundle: "foo", name: "command-with-multiple-rules"
    @description "description"
    permission "blah"

    rule "when command is foo:command-with-multiple-rules must have foo:blah"
    rule "when command is foo:command-with-multiple-rules with arg[0] == 'stuff' must have foo:admin"

    def handle_message(_,_), do: {:reply, "blah", "blah", :blah}
  end

  test "command modules are marked as such" do
    assert GenCommand.is_command?(TestCommand)
    refute GenCommand.is_command?(NotACommand)
  end

  test "commands can have no options" do
    assert %{} = GenCommand.Base.options(TestCommand)
  end

  test "commands can have one option" do
    assert %{"my_option" => %{"type" => "string", "required" => true}} = GenCommand.Base.options(CommandWithOption)
  end

  test "options default to optional and string-typed" do
    assert %{"default_option" => %{"type" => "string", "required" => false}} = GenCommand.Base.options(CommandWithDefaultOption)
  end

  test "commands can have multiple options" do
    assert %{
      "my_option" => %{"type" => "string", "required" => true, "short_flag" => nil, "description" => "my description"},
      "another_option" => %{"type" => "boolean", "required" => false, "short_flag" => nil, "description" => "another description"},
      "foooooo" => %{"type" => "string", "required" => false, "short_flag" => "f", "description" => nil}
    } == GenCommand.Base.options(CommandWithMultipleOptions)
  end

  test "commands may require no permissions by default" do
    assert [] = GenCommand.Base.permissions(TestCommand)
  end

  test "can specify a single permission for a command" do
    assert ["foo"] = GenCommand.Base.permissions(CommandWithPermission)
  end

  test "can specify multiple permissions for a command" do
    assert ["foo", "bar", "baz"] = GenCommand.Base.permissions(CommandWithMultiplePermissions)
  end

  test "can specify multiple permissions for a command at once" do
    assert ["one", "two", "three"] = GenCommand.Base.permissions(CommandWithMultiplePermissionsDeclaredAtOnce)
  end

  test "permissions can be declared with a mix of singles and multiples" do
    assert ["a", "b", "c"] = GenCommand.Base.permissions(CommandWithMixOfPermissions)
  end

  test "permissions must be specified *without* a namespace" do
    contents = quote do
      use GenCommand.Base, bundle: "foo"
      @description "description"
      permission "bundle:command" # not allowed!
      def handle_message(_,_), do: {:reply, "blah", "blah", :blah}
    end

    %ValidationError{message: message} = catch_error(Module.create(BadPermissionCommand, contents, Macro.Env.location(__ENV__)))
    assert String.starts_with?(message, "Please specify permissions without the bundle namespace: `bundle:command`")

  end

  test "commands do not need to specify any rules" do
    assert [] = GenCommand.Base.rules(TestCommand)
  end

  test "commands can specify a single rule" do
    assert ["when command is foo:command-with-rules must have foo:blah"] = GenCommand.Base.rules(CommandWithRules)
  end

  test "commands can specify multiple rules" do
    assert ["when command is foo:command-with-multiple-rules with arg[0] == 'stuff' must have foo:admin",
            "when command is foo:command-with-multiple-rules must have foo:blah"] = GenCommand.Base.rules(CommandWithMultipleRules)
  end

  test "can't compile without syntactically valid rules" do
    contents = quote do
      use GenCommand.Base, bundle: "foo"
      @description "description"
      rule "not a rule, no way, no how"
      def handle_message(_,_), do: {:reply, "blah", "blah", :blah}
    end

    %ValidationError{message: message} = catch_error(Module.create(BadRuleCommand, contents, Macro.Env.location(__ENV__)))
    assert String.starts_with?(message, "Error parsing rule \"not a rule, no way, no how\" for command \"badrulecommand\"")
  end

  test "can't compile if rule refers to a different command" do
    contents = quote do
      use GenCommand.Base, bundle: "foo", name: "my-name"
      @description "description"
      rule "when command is foo:my-command must have foo:foo"
      def handle_message(_,_), do: {:reply, "blah", "blah", :blah}
    end

    %ValidationError{message: message} = catch_error(Module.create(BadRuleCommand, contents, Macro.Env.location(__ENV__)))
    assert String.starts_with?(message, "Rule for \"my-name\" references \"my-command\": \"when command is foo:my-command must have foo:foo\"")
  end


end

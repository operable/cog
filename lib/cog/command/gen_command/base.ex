defmodule Cog.Command.GenCommand.Base do
  require Cog.Command.GenCommand.ValidationError
  alias Cog.Command.GenCommand
  alias Piper.Permissions.Ast

  @moduledoc """
  Macros for handling much of the boilerplate of command creation.

  Most of the callbacks of the `Cog.Command.GenCommand` behaviour are
  metadata-related, used to drive the automatic generation of command
  bundle configuration files. While these 0-arity functions can be
  defined directly, it can be rather verbose. Additionally, by using
  macros, we can provide compile-time checks to ensure that permission
  rules are actually syntactically valid, that they refer to the
  command being generated, etc.

  If you are writing an Elixir-based command, you should start off with

      use #{inspect __MODULE__}

  Then you'll have access to all the metadata macros, and also get a
  few other callback functions defined for you.

  ## Configuration

  You can declare various command configuration parameters in code;
  these will be introspected to automatically generate a command
  bundle.

  ### Command Name

  By default, the command name (i.e., how you will invoke the command
  via the bot, and how you will refer to it in invocation rules) is
  the lower-cased terminal segment of the module name. That is, if you
  implement a command in the `MyCompany.My.Great.Command.Foo`, then
  the command name will be `foo`.

  If you wish to override this, you should pass the desired name in
  with your `#{inspect __MODULE__}` use statement.

      defmodule This.Is.My.SuperSnazzyCommand do
        use #{inspect __MODULE__}, name: "super-command"
        # ...
      end

  ### Options

  All commands can specify options, using the `option/1` macro.

      defmodule MyCommand do
        use #{inspect __MODULE__}

        option "option_1", required: true
        option "option_2", type: "string", required: true

        # ...

      end

  These options can be inspected at runtime using
  `Cog.Command.GenCommand.Base.options/1`.

  ### Permissions

  Commands may require certain permissions to run. The union of all
  permissions of all commands in a bundle will be created in the
  system when the bundle is installed.

  Permissions may be declared using the `permission/1` macro.

      defmodule MyCommand do
        use #{inspect __MODULE__}

        permission "admin"

        # ...

      end

  Permissions can be inspected at runtime using `Cog.Command.GenCommand.Base.permissions/1`.

  ### Rules

  Upon installation, each bundle can create one or more invocation
  rules that control who is allowed to execute each command. Operators
  are free to keep these rules, delete them, edit them, or create
  their own.

  By specifying these initial rules, command authors can provide users
  with a more complete command installation experience, allowing them
  to start using commands more quickly.

  By specifying rules in code, your command will not even compile if
  the rule syntax is incorrect.

  Rules may be declared using the `rule/1` macro.

      defmodule MyCommand do
        use #{inspect __MODULE__}

        permission "admin"

        rule "when command is my-bundle:my-command must have my-bundle:admin"

        # ...
      end

  Multiple rules may be specified (just invoke `rule/1` repeatedly)

  If any rule is invalid, an error will be raised at compile time.

  Rules can be inspected at runtime using `Cog.Command.GenCommand.Base.rules/1`.
  """

  defmacro __using__(opts) do
    default_name =  __CALLER__.module
    |> Module.split
    |> List.last
    |> String.downcase

    bundle_name = Keyword.fetch!(opts, :bundle)
    command_name = Keyword.get(opts, :name, default_name)

    quote location: :keep do
      @behaviour Cog.Command.GenCommand

      require Cog.Command.GenCommand.ValidationError

      Module.register_attribute(__MODULE__, :gen_command_base, accumuate: false, persist: true)
      Module.register_attribute(__MODULE__, :bundle_name, accumulate: false, persist: true)
      Module.register_attribute(__MODULE__, :command_name, accumulate: false, persist: true)
      Module.register_attribute(__MODULE__, :description, accumulate: false, persist: true)
      Module.register_attribute(__MODULE__, :long_description, accumulate: false, persist: true)
      Module.register_attribute(__MODULE__, :examples, accumulate: false, persist: true)
      Module.register_attribute(__MODULE__, :notes, accumulate: false, persist: true)
      Module.register_attribute(__MODULE__, :arguments, accumulate: false, persist: true)
      Module.register_attribute(__MODULE__, :subcommands, accumulate: false, persist: true)
      Module.register_attribute(__MODULE__, :options, accumulate: true, persist: true)
      Module.register_attribute(__MODULE__, :permissions, accumulate: true, persist: true)
      Module.register_attribute(__MODULE__, :raw_rules, accumulate: true, persist: false)
      Module.register_attribute(__MODULE__, :rules, accumulate: true, persist: true)

      import unquote(__MODULE__), only: [option: 1,
                                         option: 2,
                                         permission: 1,
                                         rule: 1]
      @gen_command_base true
      @bundle_name unquote(bundle_name)
      @command_name unquote(command_name)

      def init(_args),
        do: {:ok, []}

      defoverridable [init: 1]

      @before_compile unquote(__MODULE__)
    end
  end

  @doc """
  Returns true if module `use`d Cog.Command.GenCommand.Base
  """
  def used_base?(module) do
    attr_value(module, :gen_command_base) == true
  end

  @doc """
  Returns bundle name embedded in compiled command file
  """
  def bundle_name(module) do
    attr_value(module, :bundle_name)
  end

  @doc """
  Returns command name embedded in compiled command file
  """
  def command_name(module) do
    attr_value(module, :command_name)
  end

  for attr <- [:description, :long_description, :examples, :notes, :arguments, :subcommands] do
    def unquote(attr)(module),
      do: attr_value(module, unquote(attr))
  end

  @doc """
  Return descriptors for all the options a command declares.

  ## Example

      > CommandWithMultipleOptions.options
      %{
        "option_1" => %{type: "string", required: true},
        "option_2" => %{type: "boolean", required: false},
        "option_3" => %{type: "string", required: false}
      }

  """
  def options(module) do
    attr_values(module, :options)
    |> Enum.reduce(%{}, fn(%{"name" => name, "type" => type, "required" => required, "short_flag" => short}, acc) ->
      Map.put(acc, name, %{"type" => type, "required" => required, "short_flag" => short})
    end)
  end

  @doc """
  Return permission rules compiled into the command file
  """
  def rules(module) do
    attr_values(module, :rules)
  end

  @doc """
  Return the names of the permissions that the command depends on.
  """
  def permissions(module) do
    attr_values(module, :permissions)
  end

  @doc """
  Declare an option that this command takes.

  This macro may be invoked multiple times, in which case all values
  are accumulated. They may be read back at runtime using
  `#{inspect __MODULE__}.options/1`.

  This metadata is used to automatically generate bundle
  configurations.

  ## Example

      option "my_option", type: "string", required: true
      option "my_option", type: "string", required: true

  ## Options

    - `type`: the datatype of a value for this option. Defaults to
      `"string"`.

    - `required`: whether or not this option must be specified for the
      command to run. Defaults to `false`.

  """
  defmacro option(name, options \\ []) do
    required = Keyword.get(options, :required, false)
    type = Keyword.get(options, :type, "string")
    short = Keyword.get(options, :short, nil)
    quote do
      @options %{"name" => unquote(name),
                 "required" => unquote(required),
                 "short_flag" => unquote(short),
                 "type" => unquote(type)}
    end
  end

  @doc """
  Declare a permission (or permissions) that this command relies on.

  This macro may be invoked multiple times, in which case all values
  are accumulated. They may be read back at runtime using
  `#{inspect __MODULE__}.permissions/1`.

  This metadata is used to automatically generate bundle
  configurations.

  When specifying a permission name, give only the name without any
  bundle namespace (that will be interpolated automatically). For
  instance, use `"foo"` instead of `"my_bundle:foo"`.

  ## Example

      permission "foo"
      permission ["foo", "bar", "baz"]

  """
  defmacro permission(name) when is_binary(name) do
    quote location: :keep, bind_quoted: [name: name] do
      if String.contains?(name, ":") do
        raise Cog.Command.GenCommand.ValidationError.new("Please specify permissions without the bundle namespace: `#{name}`")
      end
      @permissions name
    end
  end
  defmacro permission(names) when is_list(names) do
    for name <- names do
      quote do
        permission(unquote(name))
      end
    end
  end

  @doc """
  Declare an invocation rule for this command.

  This macro may be invoked multiple times, in which case all values
  are accumulated. They may be read back at runtime using
  `#{inspect __MODULE__}.rules/1`.

  This metadata is used to automatically generate bundle
  configurations.

  When defining rules, you must use the proper bundle namespace for
  permissions. That may change as this code matures.

  ## Example

      rule "when command is my-bundle:my-command must have my-bundle:admin"

  """
  defmacro rule(rule_text) do
    quote do
      @raw_rules unquote(rule_text)
    end
  end

  defmacro __before_compile__(_env) do
    alias Cog.Command.GenCommand.ValidationError

    callermod = __CALLER__.module
    command_name = Module.get_attribute(callermod, :command_name)
    raw_rules = Module.get_attribute(callermod, :raw_rules)
    rules = for rule <- raw_rules do
      case Piper.Permissions.Parser.parse(rule) do
        {:ok, %Ast.Rule{}=parsed, _} ->
          # It parsed! Save it for posterity
            rule_command_name = case String.split(parsed.command, ":", parts: 2) do
                             [_, command_name] ->
                               command_name
                             [command_name] ->
                               # Commands must be namespaced with their bundle.
                               # Bail out if that's not the case.
                               raise ValidationError.new "Rule for command #{command_name} missing bundle name: \"#{rule}\""
                           end
            # NOTE: This doesn't appear to work as a case statement
            if rule_command_name == command_name do
              rule
            else
              raise ValidationError.new "Rule for \"#{command_name}\" references \"#{rule_command_name}\": \"#{rule}\""
            end
          {:error, message} ->
            # It's invalid! bail out!
            raise ValidationError.new "Error parsing rule \"#{rule}\" for command \"#{command_name}\": #{inspect message}"
        end
    end

    # We only use GenCommand for the embedded bundle these days, and
    # this ensures that we always have a description for those commands.
    description = Module.get_attribute(callermod, :description)
    unless description do
      raise ValidationError.new "Must supply a description string for #{inspect callermod}"
    end

    quote do
      @rules unquote(rules)
    end
  end

  defp attr_value(module, attr_name) do
    if GenCommand.is_command?(module) do
      attrs = module.__info__(:attributes)
      case Keyword.get(attrs, attr_name) do
        [value] ->
          value
        nil ->
          nil
      end
    else
      nil
    end
  end

  defp attr_values(module, attr_name) do
    if GenCommand.is_command?(module) do
      attrs = module.__info__(:attributes)
      case Keyword.get_values(attrs, attr_name) do
        nil ->
          nil
        values ->
          :lists.flatten(values)
      end
    else
      nil
    end
  end

end

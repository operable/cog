defmodule Cog.GenCommand.Base do
  require Cog.GenCommand.ValidationError
  alias Cog.GenCommand
  alias Piper.Permissions.Ast

  @moduledoc """
  Macros for handling much of the boilerplate of command creation.

  Most of the callbacks of the `Cog.GenCommand` behaviour are
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

  ### Enforced/Secure Commands

  By default commands enforced, meaning they require permissions to run.
  Optionally users can opt-out and set 'enforcing' to false, requiring no
  permissions to run. Un-enforced commands should be used sparingly and are most
  useful for commands that do simple text processing and never call out to
  outside services. `operable:echo` and `operable:table` are good examples of
  un-enforced commands.

  To opt-out set the enforcing flag to false when using the command macro.
  true when using #{inspect __MODULE__}

  Example:

      defmodule MyPrimitiveCommand do
        use #{inspect __MODULE__}, enforcing: false

        # ...
      end

  ### Calling Convention

  By default commands use the 'bound' calling convention. This means commands
  only have access to variables that are explicitly passed to the command.

  For example: '@cog stackoveflow vim | echo $title'
  Echo is a bound command, it will only ever have access to the value held in '$title'.

  If a command is unenforced, meaning the 'enforcing' option is set to false and
  there are no permissions, you can set the calling convention to 'all'.
  Commands using 'all' have access to a special key on the request called
  'cog_env'. 'cog_env' contains the context that the command is currently being
  executed under.

  For example: '@cog stackoverflow vim | filter --matches="^Vim" --field="title"
  Filter is of the 'all' calling convention and therefore has access to the entire
  result map from stackoverflow.

  'all' should be used sparingly. It can potentially cause some difficult to debug
  errors if missused. It also makes it very difficult to lock down commands, hence
  the limitation on commands that have no permissions.

      defmodule MyCommand do
        use #{inspect __MODULE__}, enforcing: false

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
  `Cog.GenCommand.Base.options/1`.

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

  Permissions can be inspected at runtime using `Cog.GenCommand.Base.permissions/1`.

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

  Rules can be inspected at runtime using `Cog.GenCommand.Base.rules/1`.
  """

  defmacro __using__(opts) do
    default_name =  __CALLER__.module
    |> Module.split
    |> List.last
    |> String.downcase

    bundle_name = Keyword.fetch!(opts, :bundle)
    command_name = Keyword.get(opts, :name, default_name)
    enforcing = ensure_valid(opts, :enforcing, [true, false], true, command_name)
    execution = Atom.to_string(ensure_valid(opts, :execution, [:once, :multiple], :multiple, command_name))

    quote location: :keep do
      @behaviour Cog.GenCommand

      require Cog.GenCommand.ValidationError

      Module.register_attribute(__MODULE__, :gen_command_base, accumuate: false, persist: true)
      Module.register_attribute(__MODULE__, :bundle_name, accumulate: false, persist: true)
      Module.register_attribute(__MODULE__, :command_name, accumulate: false, persist: true)
      Module.register_attribute(__MODULE__, :options, accumulate: true, persist: true)
      Module.register_attribute(__MODULE__, :permissions, accumulate: true, persist: true)
      Module.register_attribute(__MODULE__, :raw_rules, accumulate: true, persist: false)
      Module.register_attribute(__MODULE__, :rules, accumulate: true, persist: true)
      Module.register_attribute(__MODULE__, :enforcing, accumulate: false, persist: true)
      Module.register_attribute(__MODULE__, :execution, accumulate: false, persist: true)

      import unquote(__MODULE__), only: [option: 1,
                                         option: 2,
                                         permission: 1,
                                         rule: 1]
      @gen_command_base true
      @bundle_name unquote(bundle_name)
      @command_name unquote(command_name)
      @enforcing unquote(enforcing)
      @execution unquote(execution)

      def init(_args),
        do: {:ok, []}

      defoverridable [init: 1]

      @before_compile unquote(__MODULE__)
    end
  end

  @doc """
  Returns true if module `use`d Cog.GenCommand.Base
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
    |> Enum.reduce(%{}, fn(%{"name" => name, "type" => type, "required" => required}, acc) ->
      Map.put(acc, name, %{"type" => type, "required" => required})
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
  Indicates whether a command should skip permission checks or not.
  """
  def enforcing?(module) do
    attr_value(module, :enforcing) == true
  end

  @doc """
  Return the execution method of the command
  """
  def execution(module) do
    attr_value(module, :execution)
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
    quote do
      @options %{"name" => unquote(name),
                 "required" => unquote(required),
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
        raise Cog.GenCommand.ValidationError.new("Please specify permissions without the bundle namespace: `#{name}`")
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
    alias Cog.GenCommand.ValidationError

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
    quote do
      @rules unquote(rules)
    end
  end

  defp ensure_valid(opts, opt_name, allowed, default, command_name) do
    opt_value = Keyword.get(opts, opt_name, default)
    cond do
      opt_value == default ->
        opt_value
      Enum.member?(allowed, opt_value) ->
        opt_value
      true ->
        raise ValidationError.new "Illegal option value for \"#{opt_name}\" in command \"#{command_name}\". " <>
        "Value must be one of #{inspect allowed} but found \"#{opt_value}\"."
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

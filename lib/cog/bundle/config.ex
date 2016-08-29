defmodule Cog.Bundle.Config do
  @moduledoc """
  Interact with and generate bundle configurations.

  A bundle configuration is a map that contains the following information:

  - The bundle name
  - A list of all commands in the bundle, including the command's
    invocation name, the Elixir module that implements it, and the
    various options the command may take
  - A list of permissions the bundle will create
  - A list of initial rules for the commands in the bundle, using the
    bundle permissions.

  ## Example

      %{bundle: %{name: "foo"},
        commands: [%{module: "Cog.Commands.AddRule",
                     name: "add-rule",
                     options: []},
                   %{module: "Cog.Commands.Admin",
                     name: "admin",
                     options: [%{name: "add", required: false, type: "bool"},
                               %{name: "list", required: false, type: "bool"},
                               %{name: "drop", required: false, type: "bool"},
                               %{name: "id", required: false, type: "string"},
                               %{name: "arg0", required: false, type: "string"},
                               %{name: "permission", required: false, type: "string"},
                               %{name: "for-command", required: false, type: "string"}]},
                   %{module: "Cog.Commands.Builds",
                     name: "builds",
                     options: [%{name: "state", required: true, type: "string"}]},
                   %{module: "Cog.Commands.Echo",
                     name: "echo",
                     options: []},
                   %{module: "Cog.Commands.Giphy",
                     name: "giphy",
                     options: []},
                   %{module: "Cog.Commands.Grant",
                     name: "grant",
                     options: [%{name: "command", required: true, type: "string"},
                               %{name: "permission", required: true, type: "string"},
                               %{name: "to", required: true, type: "string"}]},
                   %{module: "Cog.Commands.Greet",
                     name: "greet",
                     options: []},
                   %{module: "Cog.Commands.Math",
                     name: "math",
                     options: []},
                   %{module: "Cog.Commands.Stackoverflow",
                     name: "stackoverflow",
                     options: []},
        permissions: ["foo:admin", "foo:read", "foo:write"],
        rules: ["when command is foo:add-rule must have foo:admin",
                "when command is foo:grant must have foo:admin"]}

  """

  # TODO: Worthwhile creating structs for this?

  require Logger
  alias Cog.Command.GenCommand

  def commands(config), do: process_args(config, "commands")

  # TODO: Scope these to avoid conflicts with pre-existing modules
  # TODO: Pass each command process config from the bundle config
  def process_args(bundle_config, "commands") do
    for config <- Map.get(bundle_config, "commands", []) do
      case config do
        %{"module" => module_name} ->
          {Module.safe_concat("Elixir", module_name), []}
      end
    end
  end

  def modules(config, type) do
    for %{"module" => module_name} <- Map.get(config, type, []),
      do: Module.safe_concat("Elixir", module_name)
  end

  # TODO: This entire module is now effectively one-use private code,
  # as it is only used to generate the embedded bundle's config. We
  # can consider moving this into Cog.Bundle.Embedded, as well as
  # tailoring the code toward the embedded bundle. For instance, all
  # the arguments for `gen_config` will always be known.
  @doc """
  Generate a bundle configuration via code introspection. Returns a
  map representing the configuration, ready for turning into JSON.

  ## Arguments

  - `name`: the name of the bundle
  - `modules`: a list of modules to be included in the bundle

  """
  def gen_config(name, description, version, modules, template_dir) do
    # We create single key/value pair maps for each
    # top-level key in the overall configuration, and then merge all
    # those maps together.
    Enum.reduce([%{"cog_bundle_version" => Spanner.Config.current_config_version},
                 gen_bundle(name, description, version),
                 gen_commands(modules),
                 gen_permissions(name, modules),
                 gen_templates(template_dir)],
                &Map.merge/2)
  end

  # Generate top-level bundle configuration
  defp gen_bundle(name, description, version) do
    %{"name" => name,
      "description" => description,
      "type" => "elixir",
      "version" => version}
  end

  # Generate the union of all permissions required by commands in the
  # bundle. Returned permissions are namespaced by the bundle name.
  defp gen_permissions(bundle_name, modules) do
    permissions = modules
    |> only_commands
    |> Enum.map(&(GenCommand.Base.permissions(&1)))
    |> Enum.map(&Enum.into(&1, HashSet.new))
    |> Enum.reduce(HashSet.new, &Set.union/2)
    |> Enum.map(&namespace_permission(bundle_name, &1))
    |> Enum.sort

    %{"permissions" => permissions}
  end

  defp namespace_permission(bundle_name, permission_name),
    do: "#{bundle_name}:#{permission_name}"

  defp gen_templates(template_dir) do
    paths = Path.wildcard("#{template_dir}/*.greenbar")

    templates = Enum.reduce(paths, %{}, fn(path, acc) ->
      name = Path.basename(path, ".greenbar")
      contents = File.read!(path)
      acc = Map.put(acc, name, %{"body" => contents})
      acc
    end)
    %{"templates" => templates}
  end

  # Extract all commands from `modules` and generate configuration
  # maps for them
  defp gen_commands(modules) do
    %{"commands" => Enum.reduce(only_commands(modules), %{}, &command_map/2)}
  end

  defp only_commands(modules),
    do: Enum.filter(modules, &GenCommand.Base.used_base?/1)

  defp command_map(module, acc) do
    command =
      %{"options" => GenCommand.Base.options(module),
        "rules" => GenCommand.Base.rules(module) |> Enum.sort,
        "description" => GenCommand.Base.description(module),
        "documentation" => case Code.get_docs(module, :moduledoc) do
                             {_line, doc} ->
                               # If a module doesn't have a module doc,
                               # then it'll return a tuple of `{1, nil}`,
                               # so that works out fine here.
                               doc
                             nil ->
                               # TODO: Transition away from @moduledoc
                               # to our own thing; modules defined in
                               # test scripts apparently can access
                               # @moduledocs
                               nil
                           end,
        "module" => inspect(module)}
    Map.put(acc, GenCommand.Base.command_name(module), command)
  end

end

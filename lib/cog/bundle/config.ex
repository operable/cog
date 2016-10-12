defmodule Cog.Bundle.Config do

  require Logger
  alias Cog.Command.GenCommand

  def commands(config),
    do: process_args(config, "commands")

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
  def gen_config(name, description, version, author, homepage, modules, template_dir) do
    # We create single key/value pair maps for each
    # top-level key in the overall configuration, and then merge all
    # those maps together.
    Enum.reduce([%{"cog_bundle_version" => Spanner.Config.current_config_version},
                 gen_bundle(name, description, version, author, homepage),
                 gen_commands(modules),
                 gen_permissions(name, modules),
                 gen_templates(template_dir)],
                &Map.merge/2)
  end

  # Generate top-level bundle configuration
  defp gen_bundle(name, description, version, author, homepage) do
    %{"name" => name,
      "description" => description,
      "type" => "elixir",
      "version" => version,
      "author" => author,
      "homepage" => homepage}
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

  defp gen_templates(template_dir),
    do: %{"templates" => Cog.Repository.Templates.templates_from_files(template_dir)}

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
        "long_description" => GenCommand.Base.long_description(module),
        "examples" => GenCommand.Base.examples(module),
        "notes" => GenCommand.Base.notes(module),
        "arguments" => GenCommand.Base.arguments(module),
        "subcommands" => GenCommand.Base.subcommands(module),
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

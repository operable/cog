defmodule Cog.V1.CommandVersionView do
  use Cog.Web, :view

  alias Cog.Commands.Help.CommandFormatter

  def render("command_version.json", %{command_version: command_version}) do
    %{id: command_version.id,
      bundle: command_version.command.bundle.name,
      name: command_version.command.name,
      description: command_version.description,
      documentation: command_version.documentation}
    |> Map.merge(include(command_version, :rules))
    |> Map.merge(include(command_version, :options))
  end

  def render("command_version_help.json", %{command_version: command_version}) do
    %{name: command_version.command.name,
      description: command_version.description,
      synopsis: CommandFormatter.render_synopsis(command_version),
      required_options: CommandFormatter.render_required_options(command_version),
      options: CommandFormatter.render_options(command_version),
      subcommands: CommandFormatter.render_subcommands(command_version),
      examples: command_version.examples,
      notes: command_version.notes,
      bundle: %{
        author: command_version.bundle_version.author,
        homepage: command_version.bundle_version.homepage
      }}
  end

  defp include(command_version, :rules) do
    case Ecto.assoc_loaded?(command_version.command.rules) do
      true ->
        %{rules: render_many(command_version.command.rules, Cog.V1.RuleView, "rule.json")}
      false ->
        %{}
    end
  end

  defp include(command_version, :options) do
    case Ecto.assoc_loaded?(command_version.options) do
      true ->
        %{options: render_many(command_version.options, Cog.V1.CommandOptView, "command_opt.json")}
      false ->
        %{}
    end
  end
end

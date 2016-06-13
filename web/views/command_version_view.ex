defmodule Cog.V1.CommandVersionView do
  use Cog.Web, :view

  def render("command_version.json", %{command_version: command_version}) do
    attrs = %{id: command_version.id,
              bundle: command_version.command.bundle.name,
              name: command_version.command.name,
              description: command_version.description,
              documentation: command_version.documentation}

    case Ecto.assoc_loaded?(command_version.command.rules) do
      true ->
        Map.put(attrs, :rules, render_many(command_version.command.rules, Cog.V1.RuleView, "rule.json"))
      false ->
        attrs
    end
  end

end

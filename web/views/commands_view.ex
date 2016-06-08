defmodule Cog.V1.CommandView do
  use Cog.Web, :view

  alias Cog.V1.RuleView

  def render("command.json", %{command: command}=resource) do
    %{id: command.id,
      name: command.name,
      description: command.description,
      documentation: command.documentation}
    |> Map.merge(render_includes(resource, command))
  end

  def render("index.json", %{commands: commands}) do
    %{commands: render_many(commands, __MODULE__, "command.json", as: :command, include: :rules)}
  end

  def render("show.json", %{command: command}) do
    %{command: render_one(command, __MODULE__, "command.json", as: :command, include: :rules)}
  end

  defp render_includes(inc_fields, resource) do
    Map.get(inc_fields, :include, []) |> Enum.reduce(%{}, fn(field, reply) -> 
      case render_include(field, resource) do
        nil -> reply
        {key, value} -> Map.put(reply, key, value)
      end
    end)
  end

  defp render_include(:rules, command) do
    value = Map.fetch!(command, :rules)
    case Ecto.assoc_loaded?(value) do
      true ->
        {:rules, render_many(value, RuleView, "rule.json", as: :rule, include: [:permissions])}
      false ->
        nil
    end
  end

end

defmodule Cog.V1.RuleView do
  use Cog.Web, :view

  def render("rule.json", %{rule: rule}=resource) do
    ast = to_ast(rule)
    %{id: rule.id,
      command_name: ast.command,
      rule: to_string(ast),
      enabled: rule.enabled}
    |> Map.merge(render_includes(resource, rule))
  end

  def render("index.json", %{rules: rules}) do
    %{rules: render_many(rules, __MODULE__, "rule.json", as: :rule, include: [:permissions])}
  end

  def render("show.json", %{rule: rule}) do
    %{rule: render_one(rule, __MODULE__, "rule.json", as: :rule, include: [:permissions])}
  end

  defp to_ast(rule) do
    Piper.Permissions.Parser.json_to_rule!(rule.parse_tree)
  end

  defp render_includes(resource, rule) do
    Map.get(resource, :include, [])
    |> Enum.reduce(%{}, fn(field, reply) ->
      case render_include(field, rule) do
        nil -> reply
        {key, value} -> Map.put(reply, key, value)
      end
    end)
  end

  defp render_include(:permissions, rule) do
    value = Map.fetch!(rule, :permissions)
    case Ecto.assoc_loaded?(value) do
      true ->
        {:permissions, render_many(value, Cog.V1.PermissionView, "permission.json", as: :permission, include: [:namespace])}
      false ->
        nil
    end
  end
end

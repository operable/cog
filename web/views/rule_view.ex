defmodule Cog.V1.RuleView do
  use Cog.Web, :view

  def render("rule.json", %{rule: rule}) do
    ast = to_ast(rule)
    %{id: rule.id,
      command: ast.command,
      rule: to_string(ast)}
  end

  def render("index.json", %{rules: rules}) do
    %{rules: render_many(rules, __MODULE__, "rule.json")}
  end

  def render("show.json", %{rule: rule}) do
    %{rule: render_one(rule, __MODULE__, "rule.json")}
  end

  defp to_ast(rule) do
    Piper.Permissions.Parser.json_to_rule!(rule.parse_tree)
  end

end

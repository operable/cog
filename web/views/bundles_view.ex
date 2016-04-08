defmodule Cog.V1.BundlesView do
  use Cog.Web, :view

  alias Cog.V1.RelayGroupView
  alias Cog.V1.RuleView

  def render("bundle.json", %{bundle: bundle}=params) do
    %{id: bundle.id,
      name: bundle.name,
      enabled: bundle.enabled,
      inserted_at: bundle.inserted_at,
      updated_at: bundle.updated_at}
    |> Map.merge(render_includes(params, bundle))
  end

  def render("index.json", %{bundles: bundles}) do
    %{bundles: render_many(bundles, __MODULE__, "bundle.json", as: :bundle, include: [:commands, :relay_groups])}
  end

  def render("show.json", %{bundle: bundle}) do
    %{bundle: render_one(bundle, __MODULE__, "bundle.json", as: :bundle, include: [:commands, :relay_groups])}
  end

  def render("command.json", %{command: command}) do
    %{id: command.id,
      name: command.name,
      documentation: command.documentation,
      enforcing: command.enforcing,
      execution: command.execution,
      rules: render_many(command.rules, RuleView, "rule.json")}
  end

  defp render_includes(params, bundle) do
    Map.get(params, :include, [])
    |> Enum.reduce(%{}, fn(inc, reply) -> Map.put(reply, inc, render_include(inc, bundle)) end)
  end

  defp render_include(:commands, bundle) do
    render_many(bundle.commands, __MODULE__, "command.json", as: :command)
  end
  defp render_include(:relay_groups, bundle) do
    render_many(bundle.relay_groups, RelayGroupView, "relay_group.json")
  end

end

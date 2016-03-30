defmodule Cog.V1.BundlesView do
  use Cog.Web, :view

  def render("bundle.json", %{bundle: bundle}) do
    %{id: bundle.id,
      name: bundle.name,
      commands: render_commands(bundle.commands),
      relay_groups: render_relay_groups(bundle.relay_groups),
      enabled: bundle.enabled,
      inserted_at: bundle.inserted_at,
      updated_at: bundle.updated_at}
  end
  def render("index.json", %{bundles: bundles}) do
    %{bundles: render_many(bundles, __MODULE__, "bundle.json", as: :bundle)}
  end
  def render("show.json", %{bundle: bundle}) do
    %{bundle: render_one(bundle, __MODULE__, "bundle.json", as: :bundle)}
  end

  def render_relay_groups(groups) do
    for group <- groups do
      %{id: group.id,
        name: group.name}
    end
  end

  def render_commands(commands) do
    for command <- commands do
      %{id: command.id,
        name: command.name,
        documentation: command.documentation,
        enforcing: command.enforcing,
        execution: command.execution}
    end
  end
end

defmodule Cog.V1.RelayGroupView do
  use Cog.Web, :view

  alias Cog.V1.BundlesView
  alias Cog.V1.RelayView

  def render("relay_group.json", %{relay_group: relay_group}=params) do
    %{id: relay_group.id,
      name: relay_group.name,
      inserted_at: relay_group.inserted_at,
      updated_at: relay_group.updated_at}
    |> Map.merge(render_includes(params, relay_group))
  end

  def render("index.json", %{relay_groups: relay_groups}) do
    %{relay_groups: render_many(relay_groups, __MODULE__, "relay_group.json", include: [:relays, :bundles])}
  end
  def render("show.json", %{relay_group: relay_group}) do
    %{relay_group: render_one(relay_group, __MODULE__, "relay_group.json", include: [:relays, :bundles])}
  end
  def render("relays.json", %{relay_group: relay_group}) do
    %{relays: render_include(:relays, relay_group)}
  end
  def render("bundles.json", %{relay_group: relay_group}) do
    %{bundles: render_include(:bundles, relay_group)}
  end

  defp render_includes(params, relay_group) do
    Map.get(params, :include, [])
    |> Enum.reduce(%{}, fn(inc, reply) -> Map.put(reply, inc, render_include(inc, relay_group)) end)
  end

  defp render_include(:bundles, relay_group) do
    render_many(relay_group.bundles, BundlesView, "bundle.json", as: :bundle)
  end
  defp render_include(:relays, relay_group) do
    render_many(relay_group.relays, RelayView, "relay.json", as: :relay)
  end

end

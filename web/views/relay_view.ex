defmodule Cog.V1.RelayView do
  use Cog.Web, :view

  alias Cog.V1.RelayGroupView

  def render("relay.json", %{relay: relay}=params) do
    %{id: relay.id,
      name: relay.name,
      enabled: relay.enabled,
      description: relay.description,
      inserted_at: relay.inserted_at,
      updated_at: relay.updated_at}
    |> Map.merge(render_includes(params, relay))
  end
  def render("index.json", %{relays: relays}) do
    %{relays: render_many(relays, __MODULE__, "relay.json", include: [:groups])}
  end

  def render("show.json", %{relay: relay}) do
    %{relay: render_one(relay, __MODULE__, "relay.json", include: [:groups])}
  end

  defp render_includes(params, relay) do
    Map.get(params, :include, [])
    |> Enum.reduce(%{}, fn(inc, reply) -> Map.put(reply, inc, render_include(inc, relay)) end)
  end

  defp render_include(:groups, relay) do
    render_many(relay.groups, RelayGroupView, "relay_group.json", as: :relay_group)
  end

end

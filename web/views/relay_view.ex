defmodule Cog.V1.RelayView do
  use Cog.Web, :view

  def render("relay.json", %{relay: relay}) do
    %{id: relay.id,
      name: relay.name,
      enabled: relay.enabled,
      description: relay.description,
      groups: render_groups(relay.groups),
      inserted_at: relay.inserted_at,
      updated_at: relay.updated_at}
  end
  def render("index.json", %{relays: relays}) do
    %{relays: render_many(relays, __MODULE__, "relay.json")}
  end

  def render("show.json", %{relay: relay}) do
    %{relay: render_one(relay, __MODULE__, "relay.json")}
  end

  defp render_groups(groups) do
    for group <- groups do
      %{id: group.id,
        name: group.name}
    end
  end

end

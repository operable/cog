defmodule Cog.V1.RelayGroupView do
  use Cog.Web, :view

  alias Ecto.Association

  def render("relay_group.json", %{relay_group: relay_group}) do
    %{id: relay_group.id,
      name: relay_group.name,
      relays: render_members(relay_group.relays()),
      inserted_at: relay_group.inserted_at,
      updated_at: relay_group.updated_at}
  end
  def render("index.json", %{relay_groups: relay_groups}) do
    %{relay_groups: render_many(relay_groups, __MODULE__, "relay_group.json")}
  end
  def render("show.json", %{relay_group: relay_group}) do
    %{relay_group: render_one(relay_group, __MODULE__, "relay_group.json")}
  end
  def render("relays.json", %{relay_group: relay_group}) do
    %{relays: render_members(relay_group.relays())}
  end

  defp render_members(%Association.NotLoaded{}) do
    []
  end
  defp render_members(relays) do
    for relay <- relays do
      %{id: relay.id,
        name: relay.name}
    end
  end

end

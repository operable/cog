defmodule Cog.V1.RelayGroupMembershipController do
  use Cog.Web, :controller

  alias Cog.Models.RelayGroup
  alias Cog.Models.Bundle
  alias Cog.Models.Relay

  plug Cog.Plug.Authentication
  plug Cog.Plug.Authorization, permission: "#{Cog.embedded_bundle}:manage_relays"

  plug :put_view, Cog.V1.RelayGroupView

  def relay_index(conn, %{"id" => id}) do
    relay_group = Repo.get!(RelayGroup, id)
    |> Repo.preload([:relays])
    render(conn, "relays.json", relay_group: relay_group)
  end

  def bundle_index(conn, %{"id" => id}) do
    relay_group = Repo.get!(RelayGroup, id)
    |> Repo.preload([:bundles])
    render(conn, "bundles.json", relay_group: relay_group)
  end

  def manage_relay_membership(conn, %{"id" => id, "relays" => member_spec}),
  do: manage_association(conn, %{"id" => id, "members" => %{"relays" => member_spec}})

  def manage_bundle_assignment(conn, %{"id" => id, "bundles" => member_spec}),
  do: manage_association(conn, %{"id" => id, "members" => %{"bundles" => member_spec}})

  # Manage membership of a relay group. Adds and deletes can be submitted and
  # processed in a single request.
  def manage_association(conn, %{"id" => id, "members" => member_spec}) do
    result = Repo.transaction(fn() ->
      relay_group = Repo.get!(RelayGroup, id)

      member_keys = Map.keys(member_spec)

      members_to_add = Enum.flat_map(member_keys, &lookup_or_fail(member_spec, [&1, "add"]))
      members_to_remove = Enum.flat_map(member_keys, &lookup_or_fail(member_spec, [&1, "remove"]))

      relay_group
      |> add(members_to_add)
      |> remove(members_to_remove)
      |> Repo.preload([:bundles, :relays])
    end)

    case result do
      {:ok, relay_group} ->
        conn
        |> render("show.json", relay_group: relay_group)
    end
  end

  defp lookup_or_fail(member_spec, [kind, _operation]=path) do
    names = get_in(member_spec, path) || []
    case lookup_all(kind, names) do
      {:ok, structs} -> structs
      {:error, reason} ->
        Repo.rollback(reason)
    end
  end

  defp lookup_all(_, []), do: {:ok, []} # Don't bother with a DB lookup
  defp lookup_all(kind, names) when kind in ["relays", "bundles"] do

    type = kind_to_type(kind) # e.g. "relays" -> Relay
    unique_name_field = unique_name_field(type) # e.g. Relay -> :name

    results = Repo.all(from t in type, where: field(t, ^unique_name_field) in ^names)

    # make sure we got a result for each name given
    case length(results) == length(names) do
      true ->
        # Each name corresponds to an entity in the database
        {:ok, results}
      false ->
        # We got at least one name that doesn't map to any existing
        # user or group. Find out what's missing and report back
        retrieved_names = Enum.map(results, &Map.get(&1, unique_name_field))
        bad_names = names -- retrieved_names
        {:error, {:not_found, {kind, bad_names}}}
    end
  end

  defp add(relay_group, members) do
    Enum.each(members, &Groupable.add_to(&1, relay_group))
    relay_group
  end

  defp remove(relay_group, members) do
    Enum.each(members, &Groupable.remove_from(&1, relay_group))
    relay_group
  end


  # Given a member_spec key, return the underlying type
  defp kind_to_type("relays"), do: Relay
  defp kind_to_type("bundles"), do: Bundle

  # Given a type, return the field for its unique name
  defp unique_name_field(Relay), do: :id
  defp unique_name_field(Bundle), do: :id
end

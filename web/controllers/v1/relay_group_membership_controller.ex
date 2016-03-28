defmodule Cog.V1.RelayGroupMembershipController do
  use Cog.Web, :controller

  alias Cog.Models.Relay
  alias Cog.Models.RelayGroup
  alias Cog.Queries

  plug Cog.Plug.Authentication
  plug Cog.Plug.Authorization, permission: "#{Cog.embedded_bundle}:manage_relays"

  def index(conn, %{"id" => id}) do
    relay_group = Repo.one!(Queries.RelayGroup.for_id(id))
    render(conn, Cog.V1.RelayGroupView, "relays.json", relay_group: relay_group)
  end

  # Manage membership of a relay group. Adds and deletes can be submitted and
  # processed in a single request.
  def manage_membership(conn, %{"id" => id, "relays" => member_spec}) do
    result = Repo.transaction(fn() ->
      group = Repo.get!(RelayGroup, id)

      to_add = Enum.reduce(Map.get(member_spec, "add", []),
                           %{found: [], not_found: []}, &lookup_or_fail/2)
      to_remove = Enum.reduce(Map.get(member_spec, "remove", []),
                           %{found: [], not_found: []}, &lookup_or_fail/2)
      case to_add.not_found ++ to_remove.not_found do
        [] ->
          Queries.RelayGroup.add_relays!(group.id, to_add.found)
          removed = Queries.RelayGroup.remove_relays(group.id, to_remove.found)
          if removed != length(to_remove.found) do
            Repo.rollback(:removing_relays_failed)
          else
            Repo.preload(group, :relays)
          end
        ids ->
          Repo.rollback({:unknown_relays, ids})
      end
    end)

    case result do
      {:ok, relay_group} ->
        render(conn, Cog.V1.RelayGroupView, "show.json", relay_group: relay_group)
      {:error, reason} ->
        errors = case reason do
                   {:removing_relays_failed} ->
                     "delete_failed"
                   {:unknown_relays, ids} ->
                     %{"not_found" => %{"relays" => ids}}
                 end
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{"errors" => errors})
    end
  end

  defp lookup_or_fail(id, acc) do
    key = case Queries.Relay.exists?(id) do
            false ->
              :not_found
            true ->
              :found
          end
    Map.update(acc, key, [id], &([id|&1]))
  end

end

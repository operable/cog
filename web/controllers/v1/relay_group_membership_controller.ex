defmodule Cog.V1.RelayGroupMembershipController do
  use Cog.Web, :controller

  alias Cog.Models.RelayGroup
  alias Cog.Queries
  alias Cog.Repo

  plug Cog.Plug.Authentication
  plug Cog.Plug.Authorization, permission: "#{Cog.embedded_bundle}:manage_relays"

  def index(conn, %{"id" => id}) do
    relay_group = Repo.one!(Queries.RelayGroup.for_id(id))
    render(conn, Cog.V1.RelayGroupView, "members.json", relay_group: relay_group)
  end

  def manage_membership(conn, %{"id" => id, "relays" => member_spec}),
  do: manage_association(conn, :relay, %{"id" => id, "members" => member_spec})

  def manage_assignment(conn, %{"id" => id, "bundles" => member_spec}),
  do: manage_association(conn, :bundle, %{"id" => id, "members" => member_spec})

  # Manage membership of a relay group. Adds and deletes can be submitted and
  # processed in a single request.
  def manage_association(conn, type, %{"id" => id, "members" => member_spec}) do
    result = Repo.transaction(fn() ->
      group = Repo.one!(Queries.RelayGroup.for_id(id))
      to_add = build_members("add", type, member_spec)
      to_remove = build_members("remove", type, member_spec)

      case to_add.not_found ++ to_remove.not_found do
        [] ->
          try do
            RelayGroup.add!(type, group.id, to_add.found)
          rescue
            err in [Ecto.InvalidChangesetError] ->
              case err.changeset.errors do
                [bundle_id: _] ->
                  Repo.rollback({:add_failed, "Bundle already exists in relay group."})
                _errors ->
                  Repo.rollback({:add_failed, "Failed to add bundle to relay group."})
              end
          end
          removed = RelayGroup.remove(type, group.id, to_remove.found)
          if removed != length(to_remove.found) do
            Repo.rollback(:remove_failed)
          else
            group
          end
        ids ->
          Repo.rollback({:unknown_association, ids})
      end
    end)

    case result do
      {:ok, relay_group} ->
        relay_group = Repo.one!(Queries.RelayGroup.for_id(relay_group.id))
        render(conn, Cog.V1.RelayGroupView, "show.json", relay_group: relay_group)
      {:error, reason} ->
        errors = case reason do
                   {:add_failed, msg} ->
                     msg
                   :remove_failed ->
                     "delete_failed"
                   {:unknown_association, ids} ->
                     name = case type do
                              :relay -> :relays
                              :bundle -> :bundles
                            end
                     %{"not_found" => %{name => ids}}
                 end
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{"errors" => errors})
    end
  end

  def build_members(action, type, member_spec) do
    case Map.get(member_spec, action) do
      nil ->
        %{found: [], not_found: []}
      member_ids ->
        found = Enum.filter(member_ids, fn(id) -> verify_member(type, id) end)
        not_found = member_ids -- found
        %{found: found, not_found: not_found}
    end
  end

  defp verify_member(type, id) do
    model = case type do
              :relay  -> Cog.Models.Relay
              :bundle -> Cog.Models.Bundle
            end
    Cog.Repo.exists?(model, id)
  end

end

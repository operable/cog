defmodule Cog.V1.RelayGroupMembershipController do
  use Cog.Web, :controller

  alias Cog.Models.RelayGroup
  alias Cog.Repository.RelayGroups

  plug Cog.Plug.Authentication
  plug Cog.Plug.Authorization, permission: "#{Cog.Util.Misc.embedded_bundle}:manage_relays"

  plug :put_view, Cog.V1.RelayGroupView

  def relay_index(conn, %{"id" => id}) do
    relay_group = Repo.get!(RelayGroup, id)
    |> Repo.preload([:relays, [bundles: :versions]])
    render(conn, "relays.json", relay_group: relay_group)
  end

  def bundle_index(conn, %{"id" => id}) do
    relay_group = Repo.get!(RelayGroup, id)
    |> Repo.preload([bundles: :versions])
    render(conn, "bundles.json", relay_group: relay_group)
  end

  def manage_relay_membership(conn, %{"id" => id, "relays" => member_spec}),
    do: manage_association(conn, %{"id" => id, "members" => %{"relays" => member_spec}})

  def manage_bundle_assignment(conn, %{"id" => id, "bundles" => member_spec}),
    do: manage_association(conn, %{"id" => id, "members" => %{"bundles" => member_spec}})

  # Manage membership of a relay group. Adds and deletes can be submitted and
  # processed in a single request.
  def manage_association(conn, %{"id" => id, "members" => member_spec}) do
    relay_group = Repo.get!(RelayGroup, id)

    case RelayGroups.manage_association(relay_group, member_spec) do
      {:ok, relay_group} ->
        conn
        |> render("show.json", relay_group: relay_group)
      {:error, {:not_found, {type, ids}}} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{"errors" => %{"not_found" => %{type => ids}}})
      {:error, {:bad_id, {type, ids}}} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{"errors" => %{"bad_id" => %{type => ids}}})
      {:error, {:protected_bundle, bundle_name}} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{"errors" => %{"protected_bundle" => bundle_name}})
    end
  end

end

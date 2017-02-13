defmodule Cog.V1.RelayGroupController do
  use Cog.Web, :controller

  alias Cog.Models.RelayGroup
  alias Cog.Repository.RelayGroups
  alias Cog.Queries
  alias Cog.Repo

  plug Cog.Plug.Authentication
  plug Cog.Plug.Authorization, permission: "#{Cog.Util.Misc.embedded_bundle}:manage_relays"

  plug :scrub_params, "relay_group" when action in [:create, :update]

  def index(conn, _params) do
     groups = Repo.all(Queries.RelayGroup.all)
     render(conn, "index.json", relay_groups: groups)
  end

  def create(conn, %{"relay_group" => group_params}) do
    changeset = RelayGroup.changeset(%RelayGroup{}, group_params)

    case Repo.insert(changeset) do
      {:ok, group} ->
        conn
        |> put_status(:created)
        |> put_resp_header("location", group_path(conn, :show, group))
        |> render("show.json", relay_group: group)
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(Cog.ChangesetView, "error.json", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    group = Repo.one!(Queries.RelayGroup.for_id(id))
    render(conn, "show.json", relay_group: group)
  end

  def delete(conn, %{"id" => id}) do
    case RelayGroups.delete(id) do
      {:ok, _} ->
        send_resp(conn, :no_content, "")
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(Cog.ChangesetView, "error.json", changeset: changeset)
    end
  end

  def update(conn, %{"id" => id, "relay_group" => group_params}) do
    results = with {:ok, relay_group} <- RelayGroups.by_id(id) do
      RelayGroups.update(relay_group, group_params)
    end

    case results do
      {:ok, relay_group} ->
        render(conn, "show.json", relay_group: relay_group)
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Relay Group #{id} not found"})
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(Cog.ChangesetView, "error.json", changeset: changeset)
    end
  end

end

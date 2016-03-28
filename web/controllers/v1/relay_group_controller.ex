defmodule Cog.V1.RelayGroupController do
  use Cog.Web, :controller

  alias Cog.Models.RelayGroup
  alias Cog.Queries

  plug Cog.Plug.Authentication
  plug Cog.Plug.Authorization, permission: "#{Cog.embedded_bundle}:manage_relays"

  plug :scrub_params, "relay_group" when action in [:create, :update]

  def index(conn, _params) do
     groups = Repo.all(RelayGroup)
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
    Repo.get!(RelayGroup, id) |> Repo.delete!
    send_resp(conn, :no_content, "")
  end

  def update(conn, %{"id" => id, "relay_group" => group_params}) do
    relay_group = Repo.get!(RelayGroup, id)
    changeset = RelayGroup.changeset(relay_group, group_params)
    case Repo.update(changeset) do
      {:ok, relay_group} ->
        render(conn, "show.json", relay_group: relay_group)
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(Cog.ChangesetView, "error.json", changeset: changeset)
    end
  end

end

defmodule Cog.V1.RoleController do
  use Cog.Web, :controller

  alias Cog.Models.Role
  alias Cog.Repository.Roles

  plug Cog.Plug.Authentication
  plug Cog.Plug.Authorization, permission: "#{Cog.Util.Misc.embedded_bundle}:manage_roles"

  # Search by name only for now
  def index(conn, %{"name" => name}) do
    role = Roles.by_name(name)
    render(conn, "show.json", role: role)
  end
  def index(conn, _params) do
    roles = Roles.all()
    render(conn, "index.json", roles: roles)
  end

  def create(conn, %{"role" => params}) do
    case Roles.new(params) do
      {:ok, role} ->
        conn
        |> put_status(:created)
        |> put_resp_header("location", role_path(conn, :show, role))
        |> render("show.json", role: role)
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(Cog.ChangesetView, "error.json", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    role = Roles.by_id!(id)
    render(conn, "show.json", role: role)
  end

  def update(conn, %{"id" => id, "role" => params}) do
    case Roles.by_id!(id) |> Roles.update(params) do
      {:ok, %Role{}=role} ->
        render(conn, "show.json", role: role)
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(Cog.ChangesetView, "error.json", changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    case Roles.by_id!(id) |> Roles.delete() do
      {:ok, _} ->
        send_resp(conn, :no_content, "")
      {:error, changed} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(Cog.ChangesetView, "error.json", changeset: changed)
    end
  end

end

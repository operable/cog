defmodule Cog.V1.RoleController do
  use Cog.Web, :controller

  alias Cog.Models.Role

  plug Cog.Plug.Authentication
  plug Cog.Plug.Authorization, permission: "#{Cog.embedded_bundle}:manage_roles"

  def index(conn, _params) do
    roles = Repo.all(Role)
    |> Repo.preload(permissions: :namespace)
    render(conn, "index.json", roles: roles)
  end

  def create(conn, %{"role" => params}) do
    changeset = Role.changeset(%Role{}, params)

    case Repo.insert(changeset) do
      {:ok, role} ->
        new_role = Repo.preload(role, permissions: :namespace)
        conn
        |> put_status(:created)
        |> put_resp_header("location", role_path(conn, :show, new_role))
        |> render("show.json", role: new_role)
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(Cog.ChangesetView, "error.json", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    role = Repo.get!(Role, id)
    |> Repo.preload(permissions: :namespace)
     render(conn, "show.json", role: role)
  end

  def update(conn, %{"id" => id, "role" => role_params}) do
    case Role
    |> Repo.get!(id)
    |> Repo.preload(permissions: :namespace)
    |> Role.changeset(role_params)
    |> Repo.update do
      {:ok, %Role{}=role} ->
        render(conn, "show.json", role: role)
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(Cog.ChangesetView, "error.json", changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    Role |> Repo.get!(id) |> Repo.delete!
    send_resp(conn, :no_content, "")
  end

end

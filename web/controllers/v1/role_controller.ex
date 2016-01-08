defmodule Cog.V1.RoleController do
  use Cog.Web, :controller

  alias Cog.Models.EctoJson
  alias Cog.Models.Role

  plug Cog.Plug.Authentication
  plug Cog.Plug.Authorization, permission: "#{Cog.embedded_bundle}:manage_roles"

  def index(conn, _params) do
    roles = Repo.all(Role)
    json(conn, EctoJson.render(roles, envelope: :roles, policy: :summary))
  end

  def create(conn, %{"role" => params}) do
    changeset = Role.changeset(%Role{}, params)

    case Repo.insert(changeset) do
      {:ok, role} ->
        conn
        |> put_status(:created)
        |> put_resp_header("location", role_path(conn, :show, role))
        |> json(EctoJson.render(role, envelope: :role, policy: :detail))
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(Cog.ChangesetView, "error.json", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    role = Repo.get!(Role, id)
    json(conn, EctoJson.render(role, envelope: :role, policy: :detail))
  end

  def update(conn, %{"id" => id, "role" => role_params}) do
    case Role
    |> Repo.get!(id)
    |> Role.changeset(role_params)
    |> Repo.update do
      {:ok, %Role{}=role} ->
        json(conn, EctoJson.render(role, envelope: :role, policy: :detail))
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

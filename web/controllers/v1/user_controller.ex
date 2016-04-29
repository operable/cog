defmodule Cog.V1.UserController do
  use Cog.Web, :controller

  alias Cog.Models.User

  plug Cog.Plug.Authentication
  plug Cog.Plug.Authorization, [permission: "#{Cog.embedded_bundle}:manage_users",
                                allow_self_updates: true]

  plug :scrub_params, "user" when action in [:create, :update]

  # Search by username only for now
  def index(conn, %{"username" => name}) do
    user = Repo.get_by!(User, username: name)
    |> Repo.preload([direct_group_memberships: [roles: [permissions: :namespace]]])
    render(conn, "show.json", user: user)
  end
  def index(conn, _params) do
    users = Repo.all(User)
    |> Repo.preload([direct_group_memberships: [roles: [permissions: :namespace]]])
    render(conn, "index.json", users: users)
  end

  def create(conn, %{"user" => user_params}) do
    changeset = User.changeset(%User{}, user_params)

    case Repo.insert(changeset) do
      {:ok, user} ->
        loaded_user = Repo.preload(user, [direct_group_memberships: [roles: [permissions: :namespace]]])
        conn
        |> put_status(:created)
        |> put_resp_header("location", user_path(conn, :show, loaded_user))
        |> render("show.json", user: loaded_user)
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(Cog.ChangesetView, "error.json", changeset: changeset)
    end
  end

  def show(conn, %{"id" => "me"}) do
    show(conn, %{"id" => conn.assigns.user.id})
  end

  def show(conn, %{"id" => id}) do
    user = Repo.get!(User, id)
    |> Repo.preload([direct_group_memberships: [roles: [permissions: :namespace]]])
    render(conn, "show.json", user: user)
  end

  def update(conn, %{"id" => id, "user" => user_params}) do
    user = Repo.get!(User, id)
    changeset = User.changeset(user, user_params)

    case Repo.update(changeset) do
      {:ok, user} ->
        updated = Repo.preload(user, [direct_group_memberships: [roles: [permissions: :namespace]]])
        render(conn, "show.json", user: updated)
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(Cog.ChangesetView, "error.json", changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    user = Repo.get!(User, id)
    Repo.delete!(user)
    send_resp(conn, :no_content, "")
  end

end


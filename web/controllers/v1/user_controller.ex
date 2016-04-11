defmodule Cog.V1.UserController do
  use Cog.Web, :controller

  alias Cog.Models.User

  plug Cog.Plug.Authentication
  plug :check_self_updating, [permission: "#{Cog.embedded_bundle}:manage_users"]

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

  ###############################################
  # Plug function - local only to user controller
  #
  # This local plug allows a user to update and view
  # thieir own user information without needing
  # the "manage_users" permission.
  ###############################################
  @spec check_self_updating(Plug.Conn.t, [Keyword.t]) :: Plug.Conn.t
  defp check_self_updating(conn, opts) do
    if self_updating?(conn) do
      conn
    else
      plug_opts = Cog.Plug.Authorization.init(opts)
      Cog.Plug.Authorization.call(conn, plug_opts)
    end
  end

  @spec self_updating?(%Plug.Conn{}) :: true | false
  defp self_updating?(conn) do
    conn.private.phoenix_action in [:update, :show] and
        conn.assigns.user.id == conn.params["id"]
  end

end


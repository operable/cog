defmodule Cog.V1.UserController do
  use Cog.Web, :controller

  alias Cog.Repository.Users

  plug Cog.Plug.Authentication
  plug Cog.Plug.Authorization, [permission: "#{Cog.embedded_bundle}:manage_users",
                                self_updates_on: [:update, :show]]

  plug :scrub_params, "user" when action in [:create, :update]

  # Search by username only for now
  def index(conn, %{"username" => name}) do
    case Users.by_username(name) do
      {:ok, user} ->
        conn
        |> put_status(:ok)
        |> render("show.json", user: user)
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{errors: "User not found"})
    end
  end
  def index(conn, _params) do
    users = Users.all
    render(conn, "index.json", users: users)
  end

  def create(conn, %{"user" => user_params}) do
    case Users.new(user_params) do
      {:ok, user} ->
        conn
        |> put_status(:created)
        |> put_resp_header("location", user_path(conn, :show, user))
        |> render("show.json", user: user)
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
    case Users.by_id(id) do
      {:ok, user} ->
        conn
        |> put_status(:ok)
        |> render("show.json", user: user)
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{errors: "User not found"})
      {:error, :bad_id} ->
        conn
        |> put_status(:bad_request)
        |> json(%{errors: "Bad ID format"})
    end
  end

  def update(conn, %{"id" => id, "user" => user_params}) do
    results = with {:ok, user} <- Users.by_id(id) do
      Users.update(user, user_params)
    end

    case results do
      {:ok, updated} ->
        render(conn, "show.json", user: updated)
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{errors: "User not found"})
      {:error, :bad_id} ->
        conn
        |> put_status(:bad_request)
        |> json(%{errors: "Bad ID format"})
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(Cog.ChangesetView, "error.json", changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    results = with {:ok, user} <- Users.by_id(id) do
      Users.delete(user)
    end

    case results do
      {:ok, _} ->
        send_resp(conn, :no_content, "")
      {:error, :bad_id} ->
        conn
        |> put_status(:bad_request)
        |> json(%{errors: "Bad ID format"})
      {:error, :not_found} ->
       conn
       |> put_status(:not_found)
       |> json(%{errors: "User not found"})
    end
  end
end

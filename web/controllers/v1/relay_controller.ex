defmodule Cog.V1.RelayController do
  use Cog.Web, :controller

  alias Cog.Repository.Relays, as: RelaysRepo

  plug Cog.Plug.Authentication
  plug Cog.Plug.Authorization, permission: "#{Cog.Util.Misc.embedded_bundle}:manage_relays"

  plug :scrub_params, "relay" when action in [:create, :update]

  def index(conn, _params),
    do: render(conn, "index.json", relays: RelaysRepo.all)

  def create(conn, %{"relay" => relay_params}) do
    case RelaysRepo.new(relay_params) do
      {:ok, relay} ->
        conn
        |> put_status(:created)
        |> put_resp_header("location", relay_path(conn, :show, relay))
        |> render("show.json", relay: relay)
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(Cog.ChangesetView, "error.json", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    case RelaysRepo.by_id(id) do
      {:ok, relay} ->
        conn
        |> put_status(:ok)
        |> render("show.json", %{relay: relay})
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{errors: "Relay not found"})
      {:error, :bad_id} ->
        conn
        |> put_status(:bad_request)
        |> json(%{errors: "Bad ID format"})
    end
  end

  def delete(conn, %{"id" => id}) do
    case RelaysRepo.delete(id) do
      {:ok, _} ->
        conn
        |> send_resp(:no_content, "")
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{errors: "Relay not found"})
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

  def update(conn, %{"id" => id, "relay" => relay_params}) do
    case RelaysRepo.update(id, relay_params) do
      {:ok, updated} ->
        conn
        |> render("show.json", %{relay: updated})
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

end

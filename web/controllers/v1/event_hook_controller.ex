defmodule Cog.V1.EventHookController do
  use Cog.Web, :controller
  require Logger

  plug Cog.Plug.Authentication
  plug Cog.Plug.Authorization, permission: "#{Cog.embedded_bundle}:manage_hooks"

  alias Cog.Repository.EventHooks

  def index(conn, _params),
    do: render(conn, "index.json", event_hooks: EventHooks.all)

  def show(conn, %{"id" => id}) do
    # hook = EventHooks.hook_definition!(id)
    # render(conn, "show.json", event_hook: hook)
    case EventHooks.hook_definition(id) do
      {:ok, hook} ->
        conn
        |> put_status(:ok)
        |> render("show.json", event_hook: hook)
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{errors: "Hook not found"})
      {:error, :bad_id} ->
        conn
        |> put_status(:bad_request)
        |> json(%{errors: "Bad ID format"})
    end
  end

  def create(conn, %{"hook" => hook_params}) do
    case EventHooks.new(hook_params) do
      {:ok, hook} ->
        conn
        |> put_status(:created)
        |> put_resp_header("location", event_hook_path(conn, :show, hook))
        |> render("show.json", event_hook: hook)
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(Cog.ChangesetView, "error.json", changeset: changeset)
    end
  end

  def update(conn, %{"id" => id, "hook" => hook_params}) do
    result = with {:ok, hook} <- EventHooks.hook_definition(id),
      do: EventHooks.update(hook, hook_params)

    case result do
      {:ok, updated} ->
        render(conn, "show.json", event_hook: updated)
      {:error, :bad_id} ->
        conn
        |> put_status(:bad_request)
        |> json(%{errors: "Bad ID format"})
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{errors: "Hook not found"})
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(Cog.ChangesetView, "error.json", changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    result = with {:ok, hook} <- EventHooks.hook_definition(id),
      do: EventHooks.delete(hook)
    case result do
      {:ok, _} ->
        send_resp(conn, :no_content, "")
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{errors: "Hook not found"})
      {:error, :bad_id} ->
        conn
        |> put_status(:bad_request)
        |> json(%{errors: "Bad ID format"})
    end
  end
end

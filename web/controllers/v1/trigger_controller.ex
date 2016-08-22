defmodule Cog.V1.TriggerController do
  use Cog.Web, :controller
  require Logger

  plug Cog.Plug.Authentication
  plug Cog.Plug.Authorization, permission: "#{Cog.Util.Misc.embedded_bundle}:manage_triggers"

  alias Cog.Repository.Triggers

  # Search by name only for now; later we can expand
  def index(conn, %{"name" => name}) do
    triggers = case Triggers.by_name(name) do
                 {:ok, trigger} ->
                   [trigger]
                 {:error, :not_found} ->
                   []
               end
    render(conn, "index.json", triggers: triggers)
  end
  def index(conn, _params),
    do: render(conn, "index.json", triggers: Triggers.all)

  def show(conn, %{"id" => id}) do
    case Triggers.trigger_definition(id) do
      {:ok, trigger} ->
        conn
        |> put_status(:ok)
        |> render("show.json", trigger: trigger)
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{errors: "Trigger not found"})
      {:error, :bad_id} ->
        conn
        |> put_status(:bad_request)
        |> json(%{errors: "Bad ID format"})
    end
  end

  def create(conn, %{"trigger" => trigger_params}) do
    case Triggers.new(trigger_params) do
      {:ok, trigger} ->
        conn
        |> put_status(:created)
        |> put_resp_header("location", trigger_path(conn, :show, trigger))
        |> render("show.json", trigger: trigger)
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(Cog.ChangesetView, "error.json", changeset: changeset)
    end
  end

  def update(conn, %{"id" => id, "trigger" => trigger_params}) do
    result = with {:ok, trigger} <- Triggers.trigger_definition(id),
      do: Triggers.update(trigger, trigger_params)

    case result do
      {:ok, updated} ->
        render(conn, "show.json", trigger: updated)
      {:error, :bad_id} ->
        conn
        |> put_status(:bad_request)
        |> json(%{errors: "Bad ID format"})
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{errors: "Trigger not found"})
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(Cog.ChangesetView, "error.json", changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    result = with {:ok, trigger} <- Triggers.trigger_definition(id),
      do: Triggers.delete(trigger)
    case result do
      {:ok, _} ->
        send_resp(conn, :no_content, "")
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{errors: "Trigger not found"})
      {:error, :bad_id} ->
        conn
        |> put_status(:bad_request)
        |> json(%{errors: "Bad ID format"})
    end
  end
end

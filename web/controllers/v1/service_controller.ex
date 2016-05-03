defmodule Cog.V1.ServiceController do
  use Cog.Web, :controller
  require Logger

  alias Cog.Repository.Services

  def index(conn, _params),
    do: render(conn, "index.json", services: Services.all)

  def show(conn, %{"name" => name}) do
    case Services.service_api(name) do
      {:ok, api} ->
        conn
        |> put_status(:ok)
        |> render("show.json", service: %{name: name,
                                          api: api})
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{errors: "Service not found"})
    end
  end

end

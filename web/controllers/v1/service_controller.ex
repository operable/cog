defmodule Cog.V1.ServiceController do
  use Cog.Web, :controller
  require Logger

  alias Cog.Repository.Services

  def index(conn, _params),
    do: render(conn, "index.json", services: Services.all)

  def show(conn, %{"name" => name}) do
    case Services.deployed(name) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{errors: "Service not found"})
      service ->
        conn
        |> put_status(:ok)
        |> render("show.json", service: service)
    end
  end

end

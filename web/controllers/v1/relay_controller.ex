defmodule Cog.V1.RelayController do
  use Cog.Web, :controller

  alias Cog.Models.Relay
  alias Cog.Queries
  alias Cog.Repo

  plug Cog.Plug.Authentication
  plug Cog.Plug.Authorization, permission: "#{Cog.embedded_bundle}:manage_relays"

  plug :scrub_params, "relay" when action in [:create, :update]

  def index(conn, _params) do
    relays = Repo.all(Queries.Relay.all)
    render(conn, "index.json", relays: relays)
  end

  def create(conn, %{"relay" => relay_params}) do
    changeset = Relay.changeset(%Relay{}, relay_params)
    case Repo.insert(changeset) do
      {:ok, relay} ->
        conn
        |> put_status(:created)
        |> put_resp_header("location", relay_path(conn, :show, relay))
        |> render("show.json", %{relay: relay})
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(Cog.ChangesetView, "error.json", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    relay = Repo.one!(Queries.Relay.for_id(id))
    render(conn, "show.json", %{relay: relay})
  end

  def delete(conn, %{"id" => id}) do
    relay = Repo.get!(Relay, id)
    Repo.delete!(relay)
    send_resp(conn, :no_content, "")
  end

  def update(conn, %{"id" => id, "relay" => relay_params}) do
    relay = Repo.one!(Queries.Relay.for_id(id))
    changeset = Relay.changeset(relay, relay_params)
    case Repo.update(changeset) do
      {:ok, relay} ->
        # If the enabled flag has changed we need to enable/disable the relay
        if Map.has_key?(changeset.changes, :enabled) do
          update_relay_status(relay)
        end
        render(conn, "show.json", %{relay: relay})
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(Cog.ChangesetView, "error.json", changeset: changeset)
    end
  end

  defp update_relay_status(%Relay{enabled: true}=relay),
    do: Cog.Relay.Relays.enable_relay(relay)
  defp update_relay_status(%Relay{enabled: false}=relay),
    do: Cog.Relay.Relays.disable_relay(relay)

end

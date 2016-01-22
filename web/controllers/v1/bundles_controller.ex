defmodule Cog.V1.BundlesController do
  use Cog.Web, :controller

  alias Cog.Relay.Relays
  alias Cog.Models.Bundle
  alias Cog.Models.EctoJson
  alias Cog.Queries.Bundles

  plug Cog.Plug.Authentication
  plug Cog.Plug.Authorization, permission: "#{Cog.embedded_bundle}:manage_commands"

  def index(conn, _params) do
    installed = Repo.all(Bundles.bundle_summaries())
    json(conn, EctoJson.render(installed, envelope: :bundles, policy: :summary))
  end

  def show(conn, %{"id" => id}) do
    case Repo.one(Bundles.bundle_details(id)) do
      nil ->
        send_resp(conn, 404, Poison.encode!(%{error: "Bundle #{id} not found"}))
      bundle ->
        json(conn, EctoJson.render(bundle, envelope: :bundle,  policy: :detail))
    end
  end

  def delete(conn, %{"id" => id}) do
    case Repo.one(Bundles.bundle_summary(id)) do
      nil ->
        send_resp(conn, 404, Poison.encode!(%{error: "Bundle #{id} not found"}))
      %Bundle{name: "operable"} ->
        send_resp(conn, 403, Poison.encode!(%{error: "Cannot delete system bundle"}))
      %Bundle{name: name}=bundle ->
        :ok = Relays.drop_bundle(name)
        {:ok, _} = Repo.transaction(fn -> Repo.delete(bundle.namespace)
                                          Repo.delete(bundle) end)
        send_resp(conn, 204, "")
    end
  end

end

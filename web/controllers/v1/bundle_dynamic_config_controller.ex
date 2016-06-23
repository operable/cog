defmodule Cog.V1.BundleDynamicConfigController do
  use Cog.Web, :controller

  require Logger

  alias Cog.Router.Helpers
  alias Cog.Models.BundleDynamicConfig
  alias Cog.Repository.Bundles
  alias Cog.Repo

  plug Cog.Plug.Authentication
  plug Cog.Plug.Authorization, permission: "#{Cog.embedded_bundle}:manage_commands"

  def show(conn, %{"bundle_id" => id}) do
    case Bundles.dynamic_config_for_bundle(id) do
      nil ->
        send_resp(conn, 404, "")
      config ->
        render(conn, "show.json", dynamic_config: config)
    end
  end

  def create(conn, params) do
    changeset = BundleDynamicConfig.changeset(%BundleDynamicConfig{}, params)

    case Repo.insert(changeset) do
      {:ok, dyn_config} ->
        dyn_config = Repo.preload(dyn_config, :bundle)
        conn
        |> put_status(:created)
        |> put_resp_header("location", Helpers.bundle_dynamic_config_path(conn, :show, dyn_config.bundle_id))
        |> render("show.json", dynamic_config: dyn_config)
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(Cog.ChangesetView, "error.json", changeset: changeset)
    end
  end

  def delete(conn, %{"bundle_id" => id}) do
    if Bundles.delete_dynamic_config_for_bundle(id) do
      send_resp(conn, 204, "")
    else
      send_resp(conn, 404, "")
    end
  end

end

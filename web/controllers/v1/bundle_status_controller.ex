defmodule Cog.V1.BundleStatusController do
  use Cog.Web, :controller

  require Logger
  alias Cog.Models.Bundle
  alias Cog.Models.BundleVersion
  alias Cog.Repository

  plug Cog.Plug.Authentication
  plug Cog.Plug.Authorization, permission: "#{Cog.embedded_bundle}:manage_commands"

  def show(conn, %{"id" => id}) do
    case Repository.Bundles.bundle(id) do
      %Bundle{}=bundle ->
        json(conn, Repository.Bundles.status(bundle))
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Bundle #{id} not found"})
    end
  end

  def set_status(conn, %{"bundle_version_id" => id, "status" => desired_status}) when desired_status in ["enabled", "disabled"] do
    case Cog.Repository.Bundles.version(id) do
      %BundleVersion{}=bundle_version ->
        case Cog.Repository.Bundles.set_bundle_version_status(bundle_version, String.to_existing_atom(desired_status)) do
          :ok ->
            json(conn, Repository.Bundles.status(bundle_version.bundle))
          {:error, {:protected_bundle, name}} ->
            conn
            |> put_status(:forbidden)
            |> json(%{error: "Cannot modify the status of the #{name} bundle"})
        end
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Bundle version #{id} not found"})
    end
  end
  def set_status(conn, %{"status" => bad_status}) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Unrecognized status: #{inspect bad_status}"})
  end
  def set_status(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing 'status'. Please specify 'enabled' or 'disabled'"})
  end

end

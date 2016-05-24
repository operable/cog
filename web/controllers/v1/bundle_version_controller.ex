defmodule Cog.V1.BundleVersionController do
  use Cog.Web, :controller

  alias Cog.Models.BundleVersion
  alias Cog.Repository

  plug Cog.Plug.Authentication
  plug Cog.Plug.Authorization, permission: "#{Cog.embedded_bundle}:manage_commands"

  def show(conn, %{"bundle_version_id" => id}) do
    case Repository.Bundles.version(id) do
      %BundleVersion{}=bundle_version ->
        render(conn, "show.json", %{bundle_version: bundle_version})
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Bundle version #{id} not found"})
    end
  end

  def delete(conn, %{"bundle_version_id" => id}) do
    case Repository.Bundles.version(id) do
      %BundleVersion{}=bv ->
        case Repository.Bundles.delete(bv) do
          {:ok, _} ->
            send_resp(conn, 204, "")
          {:error, :enabled_version} ->
            conn
            |> put_status(:forbidden)
            |> json(%{error: "Cannot delete #{bv.bundle.name} #{bv.version}, because it is currently enabled"})
          {:error, {:protected_bundle, name}} ->
            conn
            |> put_status(:forbidden)
            |> json(%{error: "Cannot delete #{name} bundle version"})
        end
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Bundle version #{id} not found"})
    end
  end

end

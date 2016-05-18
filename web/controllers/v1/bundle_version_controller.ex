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
        send_resp(conn, 404, Poison.encode!(%{error: "Bundle #{id} not found"}))
    end
  end

  def delete(conn, %{"id" => id}) do
    case Repository.Bundles.version(id) do
      %BundleVersion{}=bv ->
        case Repository.Bundles.delete(bv) do
          {:ok, _} ->
            send_resp(conn, 204, "")
          {:error, {:protected_bundle, name}} ->
            send_resp(conn, 403, Poison.encode!(%{error: "Cannot delete #{name} bundle version"}))
        end
      nil ->
        send_resp(conn, 404, Poison.encode!(%{error: "Bundle #{id} not found"}))
    end
  end

end

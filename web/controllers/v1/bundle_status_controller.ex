defmodule Cog.V1.BundleStatusController do
  @moduledoc """
  Allows for reading and modifying the "status" of a bundle.

  Bundles may either be "enabled" or "disabled". If "enabled", commands
  within the bundle may be dispatched to any relays serving them. If
  "disabled", relays may continue to run the bundles, but no commands
  will be dispatched.

  The active state of a bundle is independent of whether there are any
  relays currently serving the bundle. If you, say, deactivate a
  bundle that the bot knows about, but no relays are running it, relays
  that may come online in the future serving the bundle will still not
  have commands dispatched to them.

  This provides a means of centrally, persistently, and quickly
  disabling the use of a given bundle in a Cog system.

  An example status object might look like this:

      %{bundle: "github",
        status: "enabled",
        relays: ["44a92066-b1ae-4456-8e6a-4f212bed3180"]}

  `relays` is an array of IDs of relays currently serving the given
  bundle.
  """

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
        send_resp(conn, 404, Poison.encode!(%{error: "Bundle #{id} not found"}))
    end
  end

  def set_status(conn, %{"id" => id, "status" => desired_status}) when desired_status in ["enabled", "disabled"] do
    case Cog.Repository.Bundles.version(id) do
      %BundleVersion{}=bundle_version ->
        case Cog.Repository.Bundles.set_bundle_version_status(bundle_version, String.to_existing_atom(desired_status)) do
          :ok ->
            json(conn, Repository.Bundles.status(bundle_version.bundle))
          {:error, {:protected_bundle, name}} ->
            send_resp(conn, 400, Poison.encode!(%{error: "Cannot modify the status of the #{name} bundle!"}))
        end
      nil ->
        send_resp(conn, 404, Poison.encode!(%{error: "Bundle version #{id} not found"}))
    end
  end
  def manage_status(conn, %{"status" => bad_status}),
    do: send_resp(conn, 400, Poison.encode!(%{error: "Unrecognized status: #{inspect bad_status}"}))
  def manage_status(conn, _params),
    do: send_resp(conn, 400, Poison.encode!(%{error: "Bad request"}))

end

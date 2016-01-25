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
  alias Cog.Repo
  alias Cog.Models.Bundle
  alias Cog.Queries.Bundles

  plug Cog.Plug.Authentication
  plug Cog.Plug.Authorization, permission: "#{Cog.embedded_bundle}:manage_commands"

  def show(conn, %{"id" => id}) do
    case Repo.one(Bundles.bundle_details(id)) do
      nil ->
        send_resp(conn, 404, Poison.encode!(%{error: "Bundle #{id} not found"}))
      bundle ->
        json(conn, status(bundle))
    end
  end
  def manage_status(conn, %{"id" => id, "status" => desired_status}) when desired_status in ["enabled", "disabled"] do
    case Repo.one(Bundles.bundle_details(id)) do
      nil ->
        send_resp(conn, 404, Poison.encode!(%{error: "Bundle #{id} not found"}))
      bundle ->
        if Bundle.embedded?(bundle) do
          send_resp(conn, 400, Poison.encode!(%{error: "Cannot modify the status of the embedded bundle!"}))
        else
          return = bundle
          |> make_status(desired_status)
          |> status
          json(conn, return)
        end
    end
  end
  def manage_status(conn, %{"status" => bad_status}),
    do: send_resp(conn, 400, Poison.encode!(%{error: "Unrecognized status: #{inspect bad_status}"}))
  def manage_status(conn, _params),
    do: send_resp(conn, 400, Poison.encode!(%{error: "Bad request"}))

  # Generate the response body from a bundle.
  #
  # Gives the name of the bundle, it's current activation status, and
  # a list of relays currently running the bundle (if any).
  #
  # Note that it is possible to get (and change!) the activation
  # status of a bundle known to the bot, even if no relays are
  # currently running it.
  #
  # Example:
  #
  #     %{bundle: "github",
  #       status: "enabled",
  #       relays: ["44a92066-b1ae-4456-8e6a-4f212bed3180"]}
  #
  defp status(bundle) do
    case Cog.Relay.Relays.bundle_status(bundle.name) do
      {:ok, map} ->
        %{bundle: bundle.name,
          relays: map.relays,
          status: map.status}
      {:error, :no_relays_serving_bundle} ->
        %{bundle: bundle.name,
          relays: [],
          status: (if bundle.enabled, do: "enabled", else: "disabled")}
    end
  end

  # Set the status of `bundle`, both in the database, and for any
  # currently-running relays.
  defp make_status(bundle, "enabled") do
    :ok = Cog.Relay.Relays.enable(bundle.name)
    bundle |> Bundle.enable |> Repo.update!
  end
  defp make_status(bundle, "disabled") do
    :ok = Cog.Relay.Relays.disable(bundle.name)
    bundle |> Bundle.disable |> Repo.update!
  end

end

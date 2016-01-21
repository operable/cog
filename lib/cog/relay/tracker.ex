defmodule Cog.Relay.Tracker do
  require Logger

  alias Cog.Models.Bundle

  @moduledoc """
  Represents the internal state of `Cog.Relay.Relays` and functions to
  operate on it.

  Tracks all the relays that have checked in with the bot, recording
  which bundles they each serve. Additionally, we track a bundle's
  current activation status (enabled or disabled) in order to help
  determine which relays we can dispatch to.
  """

  @type bundle_status :: :enabled | :disabled
  @type t :: %__MODULE__{map: %{String.t => %{relays: MapSet.t,
                                              status: bundle_status()}}}
  defstruct [map: %{}]

  @doc """
  Create a new, empty Tracker
  """
  @spec new() :: t
  def new(),
    do: %__MODULE__{}

  @doc """
  Removes all record of `relay` from the tracker. If `relay` is the
  last one serving a given bundle, that bundle is removed from the
  tracker as well.
  """
  @spec remove_relay(t, String.t) :: t
  def remove_relay(tracker, relay) do
    map = tracker.map
    tracker_bundles = Map.keys(map)

    map = Enum.reduce(tracker_bundles, map, fn(bundle, acc) ->
      acc = Map.update!(acc, bundle, &delete_relay(&1, relay))
      relays_remaining = get_in(acc, [bundle, :relays])
      if Enum.empty?(relays_remaining) do
        Map.delete(acc, bundle)
      else
        acc
      end
    end)

    %{tracker | map: map}
  end

  @doc """
  Records `relay` as serving each of `bundles`. If `relay` has
  previously been recorded as serving other bundles, those bundles are
  retained; this is an incremental, cumulative operation.

  If `relay` is the first to serve a bundle, the current status of the
  bundle is recorded in the tracker.
  """
  @spec add_bundles_for_relay(t, String.t, [%Bundle{}]) :: t
  def add_bundles_for_relay(tracker, relay, bundles) do
    map = Enum.reduce(bundles, tracker.map, fn(bundle, acc) ->
      initial_status = if bundle.enabled, do: :enabled, else: :disabled
      Map.update(acc, bundle.name, entry(relay, initial_status), &append_relay(&1, relay))
    end)
    %{tracker | map: map}
  end

  @doc """
  Like `add_bundles_for_relay/3` but overwrites any existing bundle
  information for `relay`. From this point, `relay` is known to only
  serve `bundles`, and no others.
  """
  @spec set_bundles_for_relay(t, String.t, [%Bundle{}]) :: t
  def set_bundles_for_relay(tracker, relay, bundles) do
    tracker
    |> remove_relay(relay)
    |> add_bundles_for_relay(relay, bundles)
  end

  @doc """
  Removes the given bundle from the tracker.
  """
  @spec drop_bundle(t, String.t) :: t
  def drop_bundle(tracker, bundle_name) do
    map = Map.delete(tracker.map, bundle_name)
    %{tracker | map: map}
  end

  @doc """
  Returns the current information for `bundle_name` in the tracker, or
  an error if the tracker does not know about `bundle_name`.

  Example:

      %{status: :enabled,
        relays: ["44a92066-b1ae-4456-8e6a-4f212ded3180",
                 "85da0992-cfcf-49b5-bc5b-d9bd53fb23cd"]}
  """
  @spec bundle_status(t, String.t) :: {:ok, map()} | {:error, :no_relays_serving_bundle}
  def bundle_status(%__MODULE__{map: map}, bundle_name) do
    case Map.get(map, bundle_name) do
      nil ->
        {:error, :no_relays_serving_bundle}
      entry ->
        {:ok, Map.update!(entry, :relays, &MapSet.to_list(&1))}
    end
  end

  @doc """
  Return a list of relays serving `bundle_name`. If the bundle is
  disabled, return an empty list.
  """
  @spec active_relays(t, String.t) :: [String.t]
  def active_relays(tracker, bundle_name) do
    case tracker do
      %__MODULE__{map: %{^bundle_name => %{status: :enabled, relays: relays}}} ->
        MapSet.to_list(relays)
      _ ->
        []
    end
  end

  @doc """
  Mark `bundle_name` as being enabled.
  """
  @spec enable_bundle(t, String.t) :: t
  def enable_bundle(tracker, bundle_name),
    do: set_status(tracker, bundle_name, :enabled)

  @doc """
  Mark `bundle_name` as being disabled.
  """
  @spec disable_bundle(t, String.t) :: t
  def disable_bundle(tracker, bundle),
    do: set_status(tracker, bundle, :disabled)

  ########################################################################

  defp entry(relay, initial_status),
    do: %{status: initial_status, relays: MapSet.new([relay])}

  defp append_relay(entry, relay),
    do: Map.update!(entry, :relays, &MapSet.put(&1, relay))

  defp delete_relay(entry, relay),
    do: Map.update!(entry, :relays, &MapSet.delete(&1, relay))

  defp set_status(tracker, bundle, status) do
    map = case Map.get(tracker.map, bundle) do
            nil ->
              tracker.map
            _ ->
              put_in(tracker.map, [bundle, :status], status)
          end
    %{tracker | map: map}
  end

end

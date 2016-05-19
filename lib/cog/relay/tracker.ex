defmodule Cog.Relay.Tracker do
  require Logger

  @moduledoc """
  Represents the internal state of `Cog.Relay.Relays` and functions to
  operate on it.

  Tracks all the relays that have checked in with the bot, recording
  which bundles they each serve.

  Maintains a set of disabled relays. Relays that appear in the disabled
  set will be filtered out when the list of relays for a bundle is requested.
  Note: Relays must be explicitly disabled, otherwise they are assumed to be
  available.
  """

  @type bundle_name :: String.t
  @type version :: String.t # e.g. "1.0.0"
  @type version_spec :: {bundle_name, version}

  @type t :: %__MODULE__{map: %{version_spec => MapSet.t}, #MapSets are of relay IDs
                         disabled: MapSet.t}

  defstruct [map: %{}, disabled: MapSet.new]

  @doc """
  Create a new, empty Tracker
  """
  @spec new() :: t
  def new(),
    do: %__MODULE__{}

  @doc """
  Enables a relay if it exists in the disabled set by removing it from the
  disabled set. When the list of relays for a bundle is requested, disabled
  bundles are filtered out.

  Note: If a relay is assigned no bundles it is unknown to the tracker. When
  enabling or disabling make sure to load bundles first or this will just be
  a noop.
  """
  @spec enable_relay(t, String.t) :: t
  def enable_relay(tracker, relay_id) do
    disabled = MapSet.delete(tracker.disabled, relay_id)
    %{tracker | disabled: disabled}
  end

  @doc """
  Disables a relay if it exists in the tracker by adding it to the disabled
  set. When the list of relays for a bundle is requested, disabled bundles
  are filtered out.

  Note: If a relay is assigned no bundles it is unknown to the tracker. When
  enabling or disabling make sure to load bundles first or this will just be
  a noop.
  """
  @spec disable_relay(t, String.t) :: t
  def disable_relay(tracker, relay_id) do
    if in_tracker?(tracker, relay_id) do
      disabled = MapSet.put(tracker.disabled, relay_id)
      %{tracker | disabled: disabled}
    else
      tracker
    end
  end

  @doc """
  Removes all record of `relay` from the tracker. If `relay` is the
  last one serving a given bundle version, that version is removed
  from the tracker as well.
  """
  @spec remove_relay(t, String.t) :: t
  def remove_relay(tracker, relay) do
    updated = Enum.reduce(tracker.map, %{}, fn({version_spec, relays}, acc) ->
      remaining = MapSet.delete(relays, relay)
      if Enum.empty?(remaining) do
        acc
      else
        Map.put(acc, version_spec, remaining)
      end
    end)

    disabled = MapSet.delete(tracker.disabled, relay)
    %{tracker | map: updated, disabled: disabled}
  end

  @doc """
  Records `relay` as serving each of `bundle_versions`. If `relay` has
  previously been recorded as serving other bundles, those bundles are
  retained; this is an incremental, cumulative operation.
  """
  @spec add_bundle_versions_for_relay(t, String.t, [version_spec]) :: t
  def add_bundle_versions_for_relay(tracker, relay, version_specs) do
    map = Enum.reduce(version_specs, tracker.map, fn(spec, acc) ->
      Map.update(acc, spec, MapSet.new([relay]), &MapSet.put(&1, relay))
    end)
    %{tracker | map: map}
  end

  @doc """
  Like `add_bundle_versions_for_relay/3` but overwrites any existing bundle
  information for `relay`. From this point, `relay` is known to only
  serve `bundle_versions`, and no others.
  """
  @spec set_bundle_versions_for_relay(t, String.t, [version_spec]) :: t
  def set_bundle_versions_for_relay(tracker, relay, version_specs) do
    tracker
    |> remove_relay(relay)
    |> add_bundle_versions_for_relay(relay, version_specs)
  end

  @doc """
  Removes the given bundle version from the tracker.
  """
  @spec drop_bundle(t, bundle_name, version) :: t
  def drop_bundle(tracker, bundle_name, version) do
    map = Map.delete(tracker.map, {bundle_name, version})
    %{tracker | map: map}
  end

  @doc """
  Return a list of relays serving the specified bundle version. If the bundle is
  disabled, return an empty list.
  """
  @spec relays(t, bundle_name, version) :: [String.t]
  def relays(tracker, bundle_name, bundle_version) when is_binary(bundle_name) do
    tracker.map
    |> Map.get({bundle_name, bundle_version}, MapSet.new)
    |> MapSet.difference(tracker.disabled)
    |> MapSet.to_list
  end

  defp in_tracker?(tracker, relay_id) do
    Map.values(tracker.map)
    |> Enum.reduce(&MapSet.union(&1, &2))
    |> MapSet.member?(relay_id)
  end
end

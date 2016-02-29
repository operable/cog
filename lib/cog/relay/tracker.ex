defmodule Cog.Relay.Tracker do
  require Logger

  alias Cog.Models.Bundle

  @moduledoc """
  Represents the internal state of `Cog.Relay.Relays` and functions to
  operate on it.

  Tracks all the relays that have checked in with the bot, recording
  which bundles they each serve.
  """

  @type t :: %__MODULE__{map: %{String.t => MapSet.t}}
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
    map = Enum.reduce(tracker.map, %{}, fn({bundle, relays}, acc) ->
      remaining = MapSet.delete(relays, relay)
      if Enum.empty?(remaining) do
        acc
      else
        Map.put(acc, bundle, remaining)
      end
    end)
    %{tracker | map: map}
  end

  @doc """
  Records `relay` as serving each of `bundles`. If `relay` has
  previously been recorded as serving other bundles, those bundles are
  retained; this is an incremental, cumulative operation.
  """
  @spec add_bundles_for_relay(t, String.t, [%Bundle{}]) :: t
  def add_bundles_for_relay(tracker, relay, bundles) do
    map = Enum.reduce(bundles, tracker.map, fn(bundle, acc) ->
      Map.update(acc, bundle.name, MapSet.new([relay]), &MapSet.put(&1, relay))
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
  Return a list of relays serving `bundle_name`. If the bundle is
  disabled, return an empty list.
  """
  @spec relays(t, String.t) :: [String.t]
  def relays(tracker, bundle_name) do
    tracker.map
    |> Map.get(bundle_name, MapSet.new)
    |> MapSet.to_list
  end

end

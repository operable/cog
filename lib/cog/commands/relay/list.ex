defmodule Cog.Commands.Relay.List do
  alias Cog.Commands.Helpers
  alias Cog.Repository.Relays

  @moduledoc """
  Lists relays.

  Usage:
  relay list [-g <group>] [-v <verbose>]

  Flags:
  -g, --group     Group relays by relay group
  -v, --verbose   Include additional relay details
  """

  @doc """
  Lists relays. Accepts a cog request and returns either a success tuple
  containing a template and data, or an error.
  """
  @spec list_relays(%Cog.Command.Request{}) :: {:ok, String.t, Map.t} | {:error, any()}
  def list_relays(req) do
    results = case Relays.all do
      [] ->
        []
      relays ->
        generate_response(req.options, relays)
    end

    {:ok, "relay-list", results}
  end

  defp generate_response(options, relays) do
    Enum.map(relays, fn(relay) ->
      relay_map = if Helpers.flag?(options, "verbose") do
        verbose_relay(relay)
      else
        standard_relay(relay)
      end

      if Helpers.flag?(options, "group") do
        Map.put(relay_map, "relay_groups", Enum.map(relay.groups, &generate_group_map/1))
        |> Map.put("_show_groups", true)
      else
        relay_map
      end
    end)
  end

  defp verbose_relay(relay) do
    %{"name" => relay.name,
     "status" => relay_status(relay.enabled),
     "id" => relay.id,
     "created_at" => relay.inserted_at}
  end

  defp standard_relay(relay) do
    %{"name" => relay.name,
     "status" => relay_status(relay.enabled)}
  end

  defp generate_group_map(relay_group) do
    %{"name" => relay_group.name}
  end

  defp relay_status(true),
    do: "enabled"
  defp relay_status(false),
    do: "disabled"
end

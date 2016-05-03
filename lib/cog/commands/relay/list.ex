defmodule Cog.Commands.Relay.List do
  alias Cog.Commands.Helpers
  alias Cog.Repository.Relays

  @moduledoc """
  Lists relays.

  Usage:
  relay list [-g <group>] [-v <verbose>] [-h <help>]

  Flags:
  -h, --help      Display this usage info
  -g, --group     Group relays by relay group
  -v, --verbose   Include additional relay details
  """

  @doc """
  Lists relays. Accepts a cog request and returns either a success tuple
  containing a template and data, or an error.
  """
  @spec list_relays(%Cog.Command.Request{}) :: {:ok, String.t, Map.t} | {:error, any()}
  def list_relays(req) do
    if Helpers.flag?(req.options, "help") do
      show_usage
    else
      case Relays.all do
        [] ->
          {:ok, "No relays configured"}
        relays ->
          {:ok, get_template(req.options), generate_response(req.options, relays)}
      end
    end
  end

  defp generate_response(options, relays) do
    Enum.map(relays, fn(relay) ->
      if Helpers.flag?(options, "group") do
        relay_map(relay)
        |> Map.put("relay_groups", Enum.map(relay.groups, &generate_group_map/1))
        |> Map.put("_show_groups", true)
      else
        relay_map(relay)
      end
    end)
  end

  defp relay_map(relay) do
    %{"name" => relay.name,
     "status" => Cog.Commands.Relay.relay_status(relay),
     "id" => relay.id,
     "created_at" => relay.inserted_at}
  end

  defp generate_group_map(relay_group) do
    %{"name" => relay_group.name}
  end

  defp get_template(options) do
    if Helpers.flag?(options, "verbose") do
      "relay-list-verbose"
    else
      "relay_list"
    end
  end

  defp show_usage do
    {:ok, "relay-usage", %{usage: @moduledoc}}
  end
end

defmodule Cog.Commands.RelayGroup.List do
  alias Cog.Commands.Helpers
  alias Cog.Repository.RelayGroups
  alias Cog.Commands.RelayGroup

  @moduledoc """
  Lists relay groups.

  Usage:
  relay-group list [-v <verbose>] [-h <help>]

  Flags:
  -h, --help      Display this usage info
  -v, --verbose   Include addition relay group details
  """

  @spec list_relay_groups(%Cog.Command.Request{}) :: {:ok, String.t, Map.t} | {:error, any()}
  def list_relay_groups(req) do
    if Helpers.flag?(req.options, "help") do
      show_usage
    else
      case RelayGroups.all do
        [] ->
          {:ok, "No relay groups configured"}
        relay_groups ->
          {:ok, get_template(req.options), generate_response(relay_groups)}
      end
    end
  end

  defp generate_response(relay_groups),
    do: Enum.map(relay_groups, &RelayGroup.json/1)

  defp get_template(options) do
    if Helpers.flag?(options, "verbose") do
      "relay-group-list-verbose"
    else
      "relay-group-list"
    end
  end

  defp show_usage do
    {:ok, "usage", %{usage: @moduledoc}}
  end
end

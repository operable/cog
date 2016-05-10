defmodule Cog.Commands.RelayGroup.Info do
  alias Cog.Commands.Helpers
  alias Cog.Repository.RelayGroups
  alias Cog.Commands.RelayGroup

  @moduledoc """
  Get info on one or more relay groups.

  USAGE
    relay-group info [<relay group names ...>] [-v <verbose>] [-h <help>]

  FLAGS
    -h, --help      Display this usage info
    -v, --verbose   Include addition relay group details
  """

  @spec relay_group_info(%Cog.Command.Request{}, List.t) :: {:ok, String.t, Map.t} | {:error, any()}
  def relay_group_info(req, args) do
    if Helpers.flag?(req.options, "help") do
      show_usage
    else
      relay_groups = if length(args) == 0 do
        case RelayGroups.all do
          [] ->
            {:ok, "No relay groups configured"}
          relay_groups ->
            {:ok, get_template(req.options), generate_response(relay_groups)}
        end
      else
        case RelayGroups.all_by_name(args) do
          [] ->
            {:ok, "No relay groups configured with name in '#{Enum.join(args, ", ")}'"}
          relay_groups ->
            {:ok, get_template(req.options), generate_response(relay_groups)}
        end
      end
    end
  end

  defp generate_response(relay_groups),
    do: Enum.map(relay_groups, &RelayGroup.json/1)

  defp get_template(options) do
    if Helpers.flag?(options, "verbose") do
      "relay-group-info-verbose"
    else
      "relay-group-info"
    end
  end

  defp show_usage do
    {:ok, "usage", %{usage: @moduledoc}}
  end
end

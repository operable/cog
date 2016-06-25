defmodule Cog.Commands.RelayGroup.List do
  alias Cog.Commands.Helpers
  alias Cog.Repository.RelayGroups
  alias Cog.Commands.RelayGroup

  @moduledoc """
  List all relay groups

  USAGE
    relay-group list [FLAGS]

  FLAGS
    -h, --help      Display this usage list
  """

  def list(req, _args) do
    if Helpers.flag?(req.options, "help") do
      show_usage
    else
      {:ok, "relay-group-list", generate_response(RelayGroups.all)}
    end
  end

  defp generate_response(relay_groups),
    do: Enum.map(relay_groups, &RelayGroup.json/1)

  defp show_usage do
    {:ok, "usage", %{usage: @moduledoc}}
  end
end

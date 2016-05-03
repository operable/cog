defmodule Cog.Commands.RelayGroup.List do
  alias Cog.Commands.Helpers

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
    end
  end

  defp show_usage do
    {:ok, "relay-group-usage", %{usage: @moduledoc}}
  end
end

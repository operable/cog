defmodule Cog.Commands.RelayGroup.Rename do
  alias Cog.Commands.Helpers

  @moduledoc """
  Renames relay groups

  Usage:
  relay-group rename [-h <help>] <old name> <new name>

  Flags:
  -h, --help      Display this usage info
  """

  @spec rename_relay_group(%Cog.Command.Request{}) :: {:ok, String.t, Map.t} | {:error, any()}
  def rename_relay_group(req) do
    if Helpers.flag?(req.options, "help") do
      show_usage
    else
    end
  end

  defp show_usage do
    {:ok, "relay-group-usage", %{usage: @moduledoc}}
  end
end






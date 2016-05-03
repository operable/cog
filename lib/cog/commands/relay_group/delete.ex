defmodule Cog.Commands.RelayGroup.Delete do
  alias Cog.Commands.Helpers

  @moduledoc """
  Deletes relay groups

  Usage:
  relay-group delete [-h <help>] <group name>

  Flags:
  -h, --help      Display this usage info
  """

  @spec delete_relay_group(%Cog.Command.Request{}) :: {:ok, String.t, Map.t} | {:error, any()}
  def delete_relay_group(req) do
    if Helpers.flag?(req.options, "help") do
      show_usage
    else
    end
  end

  defp show_usage do
    {:ok, "relay-group-usage", %{usage: @moduledoc}}
  end
end




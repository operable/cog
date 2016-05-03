defmodule Cog.Commands.RelayGroup.Remove do
  alias Cog.Commands.Helpers

  @moduledoc """
  Removes relays from relay groups

  Usage:
  relay-group remove [-h <help>] <group name> <relays ...>

  Flags:
  -h, --help      Display this usage info
  """

  @spec remove_relays(%Cog.Command.Request{}) :: {:ok, String.t, Map.t} | {:error, any()}
  def remove_relays(req) do
    if Helpers.flag?(req.options, "help") do
      show_usage
    else
    end
  end

  defp show_usage do
    {:ok, "relay-group-usage", %{usage: @moduledoc}}
  end
end





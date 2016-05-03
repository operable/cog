defmodule Cog.Commands.RelayGroup.Add do
  alias Cog.Commands.Helpers

  @moduledoc """
  Adds relays to relay groups

  Usage:
  relay-group add [-h <help>] <relay group> <relays ...>

  Flags:
  -h, --help      Display this usage info
  """

  @spec add_relays(%Cog.Command.Request{}) :: {:ok, String.t, Map.t} | {:error, any()}
  def add_relays(req) do
    if Helpers.flag?(req.options, "help") do
      show_usage
    else
    end
  end

  defp show_usage do
    {:ok, "relay-group-usage", %{usage: @moduledoc}}
  end
end

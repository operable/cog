defmodule Cog.Commands.RelayGroup.Unassign do
  alias Cog.Commands.Helpers

  @moduledoc """
  Unassigns bundles from relay groups

  Usage:
  relay-group unassign [-h <help>] <relay group> <bundles ...>

  Flags:
  -h, --help      Display this usage info
  """

  @spec unassign_bundles(%Cog.Command.Request{}) :: {:ok, String.t, Map.t} | {:error, any()}
  def unassign_bundles(req) do
    if Helpers.flag?(req.options, "help") do
      show_usage
    else
    end
  end

  defp show_usage do
    {:ok, "relay-group-usage", %{usage: @moduledoc}}
  end
end







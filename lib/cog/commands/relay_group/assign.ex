defmodule Cog.Commands.RelayGroup.Assign do
  alias Cog.Commands.Helpers

  @moduledoc """
  Assigns bundles to relay groups.

  Usage:
  relay-group assign [-h <help>] <relay group> <bundles ...>

  Flags:
  -h, --help      Display this usage info
  """

  @spec assign_bundles(%Cog.Command.Request{}) :: {:ok, String.t, Map.t} | {:error, any()}
  def assign_bundles(req) do
    if Helpers.flag?(req.options, "help") do
      show_usage
    else
    end
  end

  defp show_usage do
    {:ok, "relay-group-usage", %{usage: @moduledoc}}
  end
end


defmodule Cog.Commands.RelayGroup.Create do
  alias Cog.Commands.Helpers

  @moduledoc """
  Creates relay groups

  Usage:
  relay-group create [-h <help>] <group name>

  Flags:
  -h, --help      Display this usage info
  """

  @spec create_relay_group(%Cog.Command.Request{}) :: {:ok, String.t, Map.t} | {:error, any()}
  def create_relay_group(req) do
    if Helpers.flag?(req.options, "help") do
      show_usage
    else
    end
  end

  defp show_usage do
    {:ok, "relay-group-usage", %{usage: @moduledoc}}
  end
end



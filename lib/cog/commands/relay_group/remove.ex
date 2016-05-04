defmodule Cog.Commands.RelayGroup.Remove do
  alias Cog.Commands.Helpers
  alias Cog.Repository.RelayGroups
  alias Cog.Commands.RelayGroup

  @moduledoc """
  Removes relays from relay groups

  Usage:
  relay-group remove [-h <help>] <group name> <relays ...>

  Flags:
  -h, --help      Display this usage info
  """

  @spec remove_relays(%Cog.Command.Request{}, List.t) :: {:ok, String.t, Map.t} | {:error, any()}
  def remove_relays(req, arg_list) do
    if Helpers.flag?(req.options, "help") do
      show_usage
    else
      with {:ok, [group | relay_names]} <- Helpers.get_args(arg_list, min: 2),
           {:ok, relay_group} <- RelayGroup.Helpers.get_relay_group(group),
           {:ok, relays} <- RelayGroup.Helpers.get_relays(relay_names) do
             remove(relay_group, relays)
      end
    end
  end

  defp remove(relay_group, relays) do
    member_spec = %{"relays" => %{"remove" => Enum.map(relays, &(&1.id))}}
    case RelayGroups.manage_association(relay_group, member_spec) do
      {:ok, relay_group} ->
        {:ok, "relay-group-update-success", RelayGroup.json(relay_group)}
      error ->
        {:error, error}
    end
  end

  defp show_usage do
    {:ok, "relay-group-usage", %{usage: @moduledoc}}
  end
end





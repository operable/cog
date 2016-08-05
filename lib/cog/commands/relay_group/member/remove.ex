defmodule Cog.Commands.RelayGroup.Member.Remove do
  alias Cog.Commands.Helpers
  alias Cog.Repository.RelayGroups
  alias Cog.Commands.RelayGroup

  @moduledoc """
  Removes relays from relay groups

  USAGE
    relay-group member remove [FLAGS] <group_name> <relay_name ...>

  ARGS
    group_name   The relay group to remove relays from
    relay_name   List of relay names to remove from the relay group

  FLAGS
    -h, --help      Display this usage info
  """

  @spec remove_relays(%Cog.Messages.Command{}, List.t) :: {:ok, String.t, Map.t} | {:error, any()}
  def remove_relays(req, arg_list) do
    if Helpers.flag?(req.options, "help") do
      show_usage
    else
      case Helpers.get_args(arg_list, min: 2) do
        {:ok, [group_name | relay_names]} ->
          with {:ok, relay_group} <- RelayGroup.Helpers.get_relay_group(group_name),
               {:ok, relays} <- RelayGroup.Helpers.get_relays(relay_names) do
                 remove(relay_group, relays)
          end
        {:error, {:under_min_args, _min}} ->
          show_usage(error(:missing_args))
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

  defp error(:missing_args) do
    "Missing required args. At a minimum you must include the relay group name and at least one relay name"
  end

  defp show_usage(error \\ nil) do
    {:ok, "usage", %{usage: @moduledoc, error: error}}
  end
end

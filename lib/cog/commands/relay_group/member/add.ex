defmodule Cog.Commands.RelayGroup.Member.Add do
  alias Cog.Commands.Helpers
  alias Cog.Repository.RelayGroups
  alias Cog.Commands.RelayGroup

  @moduledoc """
  Adds relays to relay groups

  USAGE
    relay-group member add [FLAGS] <group_name> <relay_name ...>

  ARGS
    group_name    The relay group to add relays to
    relay_name    List of relay names to add to the relay group

  FLAGS
    -h, --help      Display this usage info
  """

  @spec add_relays(%Cog.Messages.Command{}, List.t) :: {:ok, String.t, Map.t} | {:error, any()}
  def add_relays(req, arg_list) do
    if Helpers.flag?(req.options, "help") do
      show_usage
    else
      case Helpers.get_args(arg_list, min: 2) do
        {:ok, [group_name | relay_names]} ->
          with {:ok, relay_group} <- RelayGroup.Helpers.get_relay_group(group_name),
               {:ok, relays} <- RelayGroup.Helpers.get_relays(relay_names),
               :ok <- verify_relays(relays, relay_names) do
                 add(relay_group, relays)
          end
        {:error, {:under_min_args, _min}} ->
          show_usage(error(:missing_args))
      end
    end
  end

  defp add(relay_group, relays) do
    member_spec = %{"relays" => %{"add" => Enum.map(relays, &(&1.id))}}
    case RelayGroups.manage_association(relay_group, member_spec) do
      {:ok, relay_group} ->
        {:ok, "relay-group-update-success", RelayGroup.json(relay_group)}
      error ->
        {:error, error}
    end
  end

  defp verify_relays(relays, relay_names) do
    case RelayGroup.Helpers.verify_list(relays, relay_names, :name) do
      :ok -> :ok
      {:error, {:values_not_found, missing}} ->
        {:error, {:relays_not_found, missing}}
    end
  end

  defp error(:missing_args) do
    "Missing required args. At a minimum you must include the relay group name and at least one relay name"
  end

  defp show_usage(error \\ nil) do
    {:ok, "usage", %{usage: @moduledoc, error: error}}
  end
end

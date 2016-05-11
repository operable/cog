defmodule Cog.Commands.RelayGroup.Add do
  alias Cog.Commands.Helpers
  alias Cog.Repository.RelayGroups
  alias Cog.Commands.RelayGroup

  @moduledoc """
  Adds relays to relay groups

  USAGE
    relay-group add [FLAGS] <relay group name> <relay names ...>

  FLAGS
    -h, --help      Display this usage info
  """

  @spec add_relays(%Cog.Command.Request{}, List.t) :: {:ok, String.t, Map.t} | {:error, any()}
  def add_relays(req, arg_list) do
    if Helpers.flag?(req.options, "help") do
      show_usage
    else
      case Helpers.get_args(arg_list, min: 2) do
        {:ok, [group | relay_names]} ->
          with {:ok, relay_group} <- RelayGroup.Helpers.get_relay_group(group),
               {:ok, relays} <- RelayGroup.Helpers.get_relays(relay_names),
               :ok <- verify_relays(relays, relay_names) do
                 add(relay_group, relays)
          end
        {:error, {:under_min_args, _min}} ->
          show_usage("Missing required args. At a minimum you must include the relay group name and at least one relay name")
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

  defp show_usage(error \\ nil) do
    {:ok, "usage", %{usage: @moduledoc, error: error}}
  end
end

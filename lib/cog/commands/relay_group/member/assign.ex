defmodule Cog.Commands.RelayGroup.Member.Assign do
  alias Cog.Commands.Helpers
  alias Cog.Repository.RelayGroups
  alias Cog.Commands.RelayGroup

  @moduledoc """
  Assigns bundles to relay groups.

  USAGE
    relay-group member assign [FLAGS] <group_name> <bundle_name ...>

  ARGS
    group_name    The relay group to assign bundles to
    bundle_name   List of bundle names to assign to the relay group

  FLAGS
    -h, --help      Display this usage info
  """

  @spec assign_bundles(%Cog.Messages.Command{}, List.t) :: {:ok, String.t, Map.t} | {:error, any()}
  def assign_bundles(req, arg_list) do
    if Helpers.flag?(req.options, "help") do
      show_usage
    else
      case Helpers.get_args(arg_list, min: 2) do
        {:ok, [group_name | bundle_names]} ->
          with {:ok, relay_group} <- RelayGroup.Helpers.get_relay_group(group_name),
               {:ok, bundles} <- RelayGroup.Helpers.get_bundles(bundle_names),
               :ok <- verify_bundles(bundles, bundle_names) do
                 assign(relay_group, bundles)
          end
        {:error, {:under_min_args, _min}} ->
          show_usage(error(:missing_args))
      end
    end
  end

  defp assign(relay_group, bundles) do
    member_spec = %{"bundles" => %{"add" => Enum.map(bundles, &(&1.id))}}
    case RelayGroups.manage_association(relay_group, member_spec) do
      {:ok, relay_group} ->
        {:ok, "relay-group-update-success", RelayGroup.json(relay_group)}
      error ->
        {:error, error}
    end
  end

  defp verify_bundles(bundles, bundle_names) do
    case RelayGroup.Helpers.verify_list(bundles, bundle_names, :name) do
      :ok -> :ok
      {:error, {:values_not_found, missing}} ->
        {:error, {:bundles_not_found, missing}}
    end
  end

  defp error(:missing_args) do
    "Missing required args. At a minimum you must include the relay group name and at least one bundle name"
  end

  defp show_usage(error \\ nil) do
    {:ok, "usage", %{usage: @moduledoc, error: error}}
  end
end

defmodule Cog.Commands.RelayGroup.Member.Unassign do
  alias Cog.Commands.Helpers
  alias Cog.Repository.RelayGroups
  alias Cog.Commands.RelayGroup

  @moduledoc """
  Unassigns bundles from relay groups

  USAGE
    relay-group member <group_name> unassign [FLAGS] <bundle_name ...>

  ARGS
    group_name   The relay group to unassign bundles from
    bundle_name  The list of bundle names to unassign from the relay group

  FLAGS
    -h, --help      Display this usage info
  """

  @spec unassign_bundles(String.t, %Cog.Command.Request{}, List.t) :: {:ok, String.t, Map.t} | {:error, any()}
  def unassign_bundles(group_name, req, arg_list) do
    if Helpers.flag?(req.options, "help") do
      show_usage
    else
      case {Helpers.get_args(arg_list, min: 1), group_name} do
        {_, nil} ->
          show_usage(error(:missing_args))
        {{:ok, bundle_names}, group_name} ->
          with {:ok, relay_group} <- RelayGroup.Helpers.get_relay_group(group_name),
               {:ok, bundles} <- RelayGroup.Helpers.get_bundles(bundle_names) do
                 unassign(relay_group, bundles)
          end
        {{:error, {:under_min_args, _min}}, _} ->
          show_usage(error(:missing_args))
      end
    end
  end

  defp unassign(relay_group, bundles) do
    member_spec = %{"bundles" => %{"remove" => Enum.map(bundles, &(&1.id))}}
    case RelayGroups.manage_association(relay_group, member_spec) do
      {:ok, relay_group} ->
        {:ok, "relay-group-update-success", RelayGroup.json(relay_group)}
      error ->
        {:error, error}
    end
  end

  defp error(:missing_args) do
    "Missing required args. At a minimum you must include the relay group name and at least one bundle name"
  end

  defp show_usage(error \\ nil) do
    {:ok, "usage", %{usage: @moduledoc, error: error}}
  end
end

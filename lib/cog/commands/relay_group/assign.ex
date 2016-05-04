defmodule Cog.Commands.RelayGroup.Assign do
  alias Cog.Commands.Helpers
  alias Cog.Repository.RelayGroups
  alias Cog.Commands.RelayGroup

  @moduledoc """
  Assigns bundles to relay groups.

  Usage:
  relay-group assign [-h <help>] <relay group> <bundles ...>

  Flags:
  -h, --help      Display this usage info
  """

  @spec assign_bundles(%Cog.Command.Request{}, List.t) :: {:ok, String.t, Map.t} | {:error, any()}
  def assign_bundles(req, arg_list) do
    if Helpers.flag?(req.options, "help") do
      show_usage
    else
      with {:ok, [group | bundle_names]} <- Helpers.get_args(arg_list, min: 2),
           {:ok, relay_group} <- RelayGroup.Helpers.get_relay_group(group),
           {:ok, bundles} <- RelayGroup.Helpers.get_bundles(bundle_names),
           :ok <- verify_bundles(bundles, bundle_names) do
             assign(relay_group, bundles)
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
    case RelayGroup.Helpers.verify_lists(bundles, bundle_names, :name) do
      :ok -> :ok
      {:error, {:values_not_found, missing}} ->
        {:error, {:bundles_not_found, missing}}
    end
  end

  defp show_usage do
    {:ok, "relay-group-usage", %{usage: @moduledoc}}
  end
end


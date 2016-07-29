defmodule Cog.Commands.RelayGroup.Rename do
  alias Cog.Commands.Helpers
  alias Cog.Repository.RelayGroups
  alias Cog.Commands.RelayGroup

  @moduledoc """
  Renames relay groups

  USAGE
    relay-group rename [FLAGS] <old_relay_name> <new_relay_name>

  ARGS
    old_relay_name    The name of the relay to rename
    new_relay_name    The new name for the relay

  FLAGS
    -h, --help      Display this usage info
  """

  @spec rename_relay_group(%Cog.Messages.Command{}, List.t) :: {:ok, String.t, Map.t} | {:error, any()}
  def rename_relay_group(req, arg_list) do
    if Helpers.flag?(req.options, "help") do
      show_usage
    else
      case Helpers.get_args(arg_list, 2) do
        {:ok, [old_name, new_name]} ->
          case RelayGroups.by_name(old_name) do
            {:ok, relay_group} ->
              rename(relay_group, new_name)
            {:error, :not_found} ->
              {:error, {:relay_group_not_found, old_name}}
          end
        {:error, {:not_enough_args, _count}} ->
          show_usage("Missing required arguments. Old relay name and new relay name are both required.")
        {:error, {:too_many_args, _count}} ->
          show_usage("Too many arguments. You can only rename one relay group at a time")
        error ->
          error
      end
    end
  end

  defp rename(relay_group, new_name) do
    case RelayGroups.update(relay_group, %{name: new_name}) do
      {:ok, updated_relay_group} ->
        json = %{old_name: relay_group.name,
                 relay_group: RelayGroup.json(updated_relay_group)}
        {:ok, "relay-group-rename", json}
      {:error, changeset} ->
        {:error, {:db_errors, changeset.errors}}
    end
  end

  def show_usage(error \\ nil) do
    {:ok, "usage", %{usage: @moduledoc, error: error}}
  end
end

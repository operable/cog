defmodule Cog.Commands.RelayGroup.Delete do
  alias Cog.Commands.Helpers
  alias Cog.Repository.RelayGroups
  alias Cog.Commands.RelayGroup

  @moduledoc """
  Deletes relay groups

  USAGE
    relay-group delete [FLAGS] <group_name>

  ARGS
    group_name    The name of the relay group to delete

  FLAGS
    -h, --help      Display this usage info
  """

  @spec delete_relay_group(%Cog.Messages.Command{}, List.t) :: {:ok, String.t, Map.t} | {:error, any()}
  def delete_relay_group(req, arg_list) do
    if Helpers.flag?(req.options, "help") do
      show_usage
    else
      case Helpers.get_args(arg_list, 1) do
        {:ok, [group_name]} ->
          case RelayGroups.by_name(group_name) do
            {:ok, relay_group} ->
              delete(relay_group)
            {:error, :not_found} ->
              {:error, {:relay_group_not_found, group_name}}
          end
        {:error, {:not_enough_args, _count}} ->
          show_usage("Missing required arguments: group name")
        {:error, {:too_many_args, _count}} ->
          show_usage("Too many arguments. You can only delete one relay group at a time")
        error ->
          error
      end
    end
  end

  defp delete(relay_group) do
    case RelayGroups.delete(relay_group) do
      {:ok, _deleted} ->
        {:ok, "relay-group-delete", RelayGroup.json(relay_group)}
      {:error, changeset} ->
        {:error, {:db_errors, changeset.errors}}
    end
  end

  def show_usage(error \\ nil) do
    {:ok, "usage", %{usage: @moduledoc, error: error}}
  end
end

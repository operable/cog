defmodule Cog.Commands.RelayGroup.Delete do
  alias Cog.Commands.Helpers
  alias Cog.Repository.RelayGroups

  @moduledoc """
  Deletes relay groups

  Usage:
  relay-group delete [-h <help>] <group name>

  Flags:
  -h, --help      Display this usage info
  """

  @spec delete_relay_group(%Cog.Command.Request{}, List.t) :: {:ok, String.t, Map.t} | {:error, any()}
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
              {:error, {:relay_group_no_found, group_name}}
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
      {:ok, relay_group} ->
        {:ok, "relay-group-delete", generate_response(relay_group)}
      {:error, changeset} ->
        {:error, {:db_errors, changeset.errors}}
    end
  end

  defp generate_response(relay_group) do
    %{"name" => relay_group.name,
      "id" => relay_group.id}
  end

  def show_usage(error \\ nil) do
    {:ok, "usage", %{usage: @moduledoc, error: error}}
  end
end




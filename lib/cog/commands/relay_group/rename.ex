defmodule Cog.Commands.RelayGroup.Rename do
  alias Cog.Commands.Helpers
  alias Cog.Repository.RelayGroups

  @moduledoc """
  Renames relay groups

  Usage:
  relay-group rename [-h <help>] <old name> <new name>

  Flags:
  -h, --help      Display this usage info
  """

  @spec rename_relay_group(%Cog.Command.Request{}, List.t) :: {:ok, String.t, Map.t} | {:error, any()}
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
          show_usage("Missing required arguments. Old name and new name are both required.")
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
        {:ok, "relay-group-rename", generate_response(updated_relay_group)}
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

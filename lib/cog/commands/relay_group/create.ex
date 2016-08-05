defmodule Cog.Commands.RelayGroup.Create do
  alias Cog.Commands.Helpers
  alias Cog.Repository.RelayGroups
  alias Cog.Commands.RelayGroup

  @moduledoc """
  Creates relay groups

  USAGE
    relay-group create [FLAGS] <group_name>

  ARGS
    group_name    The name of the relay group to create

  FLAGS
    -h, --help      Display this usage info
  """

  @spec create_relay_group(%Cog.Messages.Command{}, List.t) :: {:ok, String.t, Map.t} | {:error, any()}
  def create_relay_group(req, arg_list) do
    if Helpers.flag?(req.options, "help") do
      show_usage
    else
      case Helpers.get_args(arg_list, 1) do
        {:ok, [name]} ->
          case RelayGroups.new(%{name: name}) do
            {:ok, relay_group} ->
              {:ok, "relay-group-create", RelayGroup.json(relay_group)}
            {:error, changeset} ->
              {:error, {:db_errors, changeset.errors}}
          end
        {:error, {:not_enough_args, _count}} ->
          show_usage("Missing required argument: group name")
        {:error, {:too_many_args, _count}} ->
          show_usage("Too many arguments. You can only create one relay group at a time")
        error ->
          error
      end
    end
  end

  defp show_usage(error \\ nil) do
    {:ok, "usage", %{usage: @moduledoc, error: error}}
  end
end

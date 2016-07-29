defmodule Cog.Commands.Group.Info do
  require Cog.Commands.Helpers, as: Helpers
  alias Cog.Repository.Groups

  Helpers.usage """
  Get info about a user group.

  USAGE
    group info <group-name>

  ARGS
    group-name    The user group name to get info about

  FLAGS
    -h, --help    Display this usage info
  """

  @spec get_info(%Cog.Messages.Command{}, List.t) :: {:ok, String.t, Map.t} | {:error, any()}
  def get_info(req, arg_list) do
    if Helpers.flag?(req.options, "help") do
      show_usage
    else
      case Helpers.get_args(arg_list, 1) do
        {:ok, [group_name]} ->
          case Groups.by_name(group_name) do
            {:ok, group} ->
              {:ok, "user-group-info", group}
            {:error, :not_found} ->
              {:error, {:resource_not_found, "user group", group_name}}
          end
        {:error, {:not_enough_args, _}} ->
          show_usage("Missing required argument: group_name")
        {:error, {:too_many_args, _}} ->
          show_usage("Too many arguments. You can only get info for one user group at a time.")
      end
    end
  end
end

defmodule Cog.Commands.Group.Delete do
  require Cog.Commands.Helpers, as: Helpers
  alias Cog.Repository.Groups

  Helpers.usage """
  Deletes user groups.

  USAGE
    group delete [FLAGS] <group-name>

  ARGS
    group-name    The name of the user group to delete

  FLAGS
    -h, --help    Display this usage info
  """

  @spec delete_group(%Cog.Messages.Command{}, List.t) :: {:ok, String.t, Map.t} | {:error, any()}
  def delete_group(req, arg_list) do
    if Helpers.flag?(req.options, "help") do
      show_usage
    else
      case Helpers.get_args(arg_list, 1) do
        {:ok, [group_name]} ->
          case Groups.by_name(group_name) do
            {:ok, group} ->
              delete(group)
            {:error, :not_found} ->
              {:error, {:resource_not_found, "user group", group_name}}
          end
        {:error, {:not_enough_args, _}} ->
          show_usage("Missing required argument: group_name")
        {:error, {:too_many_args, _}} ->
          show_usage("Too many arguments. You can only delete one user group at a time.")
      end
    end
  end

  defp delete(group) do
    case Groups.delete(group) do
      {:ok, _deleted} ->
        {:ok, "user-group-delete", group}
      {:error, changeset} ->
        {:error, {:db_errors, changeset.errors}}
    end
  end
end

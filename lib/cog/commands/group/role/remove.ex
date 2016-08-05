defmodule Cog.Commands.Group.Role.Remove do
  require Cog.Commands.Helpers, as: Helpers
  alias Cog.Repository.Groups

  Helpers.usage """
  Remove roles from user groups.

  USAGE
    group role remove [FLAGS] <group-name> <role-name ...>

  ARGS
    group-name    The group to remove roles from
    role-name     List of one or more roles to remove from the group

  FLAGS
    -h, --help    Display this usage info
  """

  @spec remove_role(%Cog.Messages.Command{}, List.t) :: {:ok, String.t, Map.t} | {:error, any()}
  def remove_role(req, arg_list) do
    if Helpers.flag?(req.options, "help") do
      show_usage
    else
      case Helpers.get_args(arg_list, min: 2) do
        {:ok, [group_name | role_names]} ->
          case remove(group_name, role_names) do
            {:ok, group} ->
              {:ok, "user-group-update-success", group}
            {:error, {:not_found, {kind, bad_names}}} ->
              {:error, {:resource_not_found, kind, Enum.join(bad_names, ", ")}}
            {:error, error} ->
              {:error, {:db_errors, error}}
          end
        {:error, {:under_min_args, _min}} ->
          show_usage(error(:missing_args))
      end
    end
  end

  defp remove(group_name, role_names) do
    case Groups.by_name(group_name) do
      {:ok, group} ->
        Groups.manage_membership(group, %{"members" => %{"roles" => %{"remove" => role_names}}})
      {:error, :not_found} ->
        {:error, {:resource_not_found, "user group", group_name}}
    end
  end

  defp error(:missing_args) do
    "Missing required args. At a minimum you must include the user group and at least one role name to remove"
  end
end

defmodule Cog.Commands.Group.Member.Add do
  require Cog.Commands.Helpers, as: Helpers
  alias Cog.Commands.Group
  alias Cog.Repository.Groups

  Helpers.usage """
  Add users to user groups.

  USAGE
    group member add [FLAGS] <group_name> <user_name ...>

  ARGS
    group_name    The group to add users to
    user_name     List of one or more users to add to the group

  FLAGS
    -h, --help    Display this usage info
  """

  @spec add_user(%Cog.Command.Request{}, List.t) :: {:ok, String.t, Map.t} | {:error, any()}
  def add_user(req, arg_list) do
    if Helpers.flag?(req.options, "help") do
      show_usage
    else
      case Helpers.get_args(arg_list, min: 2) do
        {:ok, [group_name | usernames]} ->
          add(group_name, usernames)
        {:error, {:under_min_args, _min}} ->
          show_usage(error(:missing_args))
      end
    end
  end

  defp add(group_name, usernames) do
    case Groups.by_name(group_name) do
      {:ok, group} ->
        IO.inspect group
      {:error, :not_found} ->
        {:error, {:resource_not_found, "user group", group_name}}
    end
  end

  defp error(:missing_args) do
    "Missing required args. At a minimum you must include the user group and at least one user name to add"
  end
end

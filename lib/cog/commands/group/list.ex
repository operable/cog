defmodule Cog.Commands.Group.List do
  alias Cog.Commands.Helpers
  alias Cog.Commands.Group
  alias Cog.Repository.Groups

  @moduledoc """
  Lists user groups. Optionally you can pass a list of group names to
  display. Group names that don't exist will be ignored.

  USAGE
    group list [FLAGS] [group_name ...]

  ARGS
    group_name    List of one or more group names to display

  FLAGS
    -h, --help    Display this usage info
    -v, --verbose Display additional info for groups
  """

  @spec list_users(%Cog.Command.Request{}, List.t) :: {:ok, String.t, Map.t} | {:error, any()}
  def list_users(req, arg_list) do
    if Helpers.flag?(req.options, "help") do
      show_usage
    else
      if length(arg_list) == 0 do
        case Groups.all do
          [] ->
            {:ok, "Currently, there are no groups in the system"}
          groups ->
            {:ok, get_template(req.options), Enum.map(groups, &Group.json/1)}
        end
      else
        case Groups.all_by_name(arg_list) do
          [] ->
            {:ok, "There are no groups with a name in '#{Enum.join(arg_list, ", ")}'"}
          groups ->
            {:ok, get_template(req.options), Enum.map(groups, &Group.json/1)}
        end
      end
    end
  end

  defp get_template(options) do
    if Helpers.flag?(options, "verbose") do
      "user-group-list-verbose"
    else
      "user-group-list"
    end
  end

  defp show_usage(error \\ nil) do
    {:ok, "usage", %{usage: @moduledoc, error: error}}
  end
end

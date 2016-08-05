defmodule Cog.Commands.Group.List do
  require Cog.Commands.Helpers, as: Helpers
  alias Cog.Repository.Groups

  Helpers.usage """
  Lists user groups.

  USAGE
    group list [FLAGS]

  FLAGS
    -h, --help    Display this usage info
    -v, --verbose Display additional info for groups
  """

  @spec list_groups(%Cog.Messages.Command{}, List.t) :: {:ok, String.t, Map.t} | {:error, any()}
  def list_groups(req, _arg_list) do
    if Helpers.flag?(req.options, "help") do
      show_usage
    else
      case Groups.all do
        [] ->
          {:ok, "Currently, there are no groups in the system."}
        groups ->
          {:ok, get_template(req.options), groups}
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
end

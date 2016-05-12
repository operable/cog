defmodule Cog.Commands.Group.List do
  alias Cog.Commands.Helpers
  alias Cog.Commands.Group
  alias Cog.Repo
  alias Cog.Models

  @moduledoc """
  Lists user groups

  USAGE
    group list [FLAGS]

  FLAGS
    -h, --help    Display this usage info
    -v, --verbose Display additional info for groups
  """

  @spec list_users(%Cog.Command.Request{}, List.t) :: {:ok, String.t, Map.t} | {:error, any()}
  def list_users(req, _arg_list) do
    if Helpers.flag?(req.options, "help") do
      show_usage
    else
      case Repo.all(Models.Group) do
        [] ->
          {:ok, "Currently, there are no groups in the system"}
        groups ->
          groups = Repo.preload(groups, [:roles, :permissions, :direct_user_members])
          {:ok, get_template(req.options), Enum.map(groups, &Group.json/1)}
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

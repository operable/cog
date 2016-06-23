defmodule Cog.Commands.Permission.List do
  alias Cog.Repository.Permissions
  require Cog.Commands.Helpers, as: Helpers

  Helpers.usage """
  List all permissions.

  USAGE
    permission list [FLAGS]

  FLAGS
    -h, --help  Display this usage info
  """

  def list(%{options: %{"help" => true}}, _args),
    do: show_usage
  def list(_req, _args) do
    rendered = Cog.V1.PermissionView.render("index.json", %{permissions: Permissions.all})
    {:ok, "permission-list", rendered[:permissions]}
  end

end

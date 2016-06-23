defmodule Cog.Commands.Role.List do
  alias Cog.Repository.Roles
  require Cog.Commands.Helpers, as: Helpers

  Helpers.usage """
  List all roles.

  USAGE
    role list [FLAGS]

  FLAGS
    -h, --help  Display this usage info
  """

  def list(%{options: %{"help" => true}}, _args),
    do: show_usage
  def list(_req, _args) do
    rendered = Cog.V1.RoleView.render("index.json", %{roles: Roles.all})
    {:ok, "role-list", rendered[:roles]}
  end

end

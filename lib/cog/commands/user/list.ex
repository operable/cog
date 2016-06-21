defmodule Cog.Commands.User.List do
  alias Cog.Repository.Users
  require Cog.Commands.Helpers, as: Helpers

  Helpers.usage """
  List all users.

  USAGE
    user list [FLAGS]

  FLAGS
    -h, --help  Display this usage info
  """

  def list(%{options: %{"help" => true}}, _args) do
    show_usage
  end
  def list(_req, _args) do
    rendered = Cog.V1.UserView.render("index.json", %{users: Users.all})
    {:ok, "user-list", rendered[:users]}
  end

end

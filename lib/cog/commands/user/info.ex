defmodule Cog.Commands.User.Info do
  alias Cog.Repository.Users
  require Cog.Commands.Helpers, as: Helpers

  Helpers.usage """
  Show detailed information about a specific user.

  USAGE
    user info [FLAGS] <username>

  ARGS
    username   The name of a user

  FLAGS
    -h, --help  Display this usage info
  """

  def info(%{options: %{"help" => true}}, _args) do
    show_usage
  end
  def info(_req, [user_name]) do
    case Users.by_username(user_name) do
      {:error, :not_found} ->
        {:error, {:resource_not_found, "user", user_name}}
      {:ok, user} ->
        rendered = Cog.V1.UserView.render("show.json", %{user: user})
        {:ok, "user-info", rendered[:user]}
    end
  end
  def info(_req, []),
    do: {:error, {:not_enough_args, 1}}
  def info(_req, _),
    do: {:error, {:too_many_args, 1}}

end

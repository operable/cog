defmodule Cog.Commands.Permission.Create do
  alias Cog.Repository.Permissions
  require Cog.Commands.Helpers, as: Helpers

  Helpers.usage """
  Create a new site permission.

  USAGE
    permission create [FLAGS] site:<name>

  FLAGS
    -h, --help  Display this usage info

  ARGS
    name     The name of the permission to create.

  EXAMPLE

    permission create site:foo

  """

  def create(%{options: %{"help" => true}}, _args),
    do: show_usage
  def create(_req, [<<"site:", name :: binary>>]) do
    case Permissions.create_permission(name) do
      {:ok, permission} ->
        rendered = Cog.V1.PermissionView.render("show.json", %{permission: permission})
        {:ok, "permission-create", rendered[:permission]}
      {:error, _}=error ->
        error
    end
  end
  def create(_req, [_invalid_permission]),
    do: {:error, :invalid_permission}
  def create(_req, []),
    do: {:error, {:not_enough_args, 1}}
  def create(_req, _),
    do: {:error, {:too_many_args, 1}}

end

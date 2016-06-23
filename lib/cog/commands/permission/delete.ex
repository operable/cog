defmodule Cog.Commands.Permission.Delete do
  require Cog.Commands.Helpers, as: Helpers

  alias Cog.Repository.Permissions
  alias Cog.Models.Permission

  Helpers.usage """
  Delete a site permission.

  USAGE
    permission delete [FLAGS] site:<name>

  FLAGS
    -h, --help  Display this usage info

  ARGS
    name     The permission to delete

  EXAMPLE

    permission delete site:foo

  """

  def delete(%{options: %{"help" => true}}, _args),
    do: show_usage
  def delete(_req, [<<"site:", _name :: binary>>=permission_name]) do
    case Permissions.by_name(permission_name) do
      %Permission{}=permission ->
        Permissions.delete(permission)
        rendered = Cog.V1.PermissionView.render("show.json", %{permission: permission})
        {:ok, "permission-delete", rendered[:permission]}
      nil ->
        {:error, {:resource_not_found, "permission", permission_name}}
    end
  end
  def delete(_req, [_invalid_permission]),
    do: {:error, :invalid_permission}
  def delete(_req, []),
    do: {:error, {:not_enough_args, 1}}
  def delete(_req, _),
    do: {:error, {:too_many_args, 1}}

end

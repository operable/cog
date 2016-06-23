defmodule Cog.Commands.Permission.Revoke do
  alias Cog.Repository.Permissions
  alias Cog.Repository.Roles

  alias Cog.Models.Permission
  alias Cog.Models.Role

  require Cog.Commands.Helpers, as: Helpers

  Helpers.usage """
  Revoke a permission from a role. Unlike `create` and `delete`, you
  can grant any permission to a role, not just site permissions.

  USAGE
    permission revoke [FLAGS] <permission> <role>

  FLAGS
    -h, --help  Display this usage info

  ARGS
    permission   The name of the permission to revoke. Must be the full, bundle-scoped name
    role         The name of the role to revoke the permission from

  EXAMPLE

    permission revoke site:foo dev

  """

  def revoke(%{options: %{"help" => true}}, _args),
    do: show_usage
  def revoke(_req, [permission, role]) when is_binary(permission) and is_binary(role) do
    case Permissions.by_name(permission) do
      %Permission{}=permission ->
        case Roles.by_name(role) do
          %Role{}=role ->
            role = Roles.revoke(role, permission)
            permission = Cog.V1.PermissionView.render("show.json", %{permission: permission})
            role       = Cog.V1.RoleView.render("show.json", %{role: role})
            {:ok, "permission-revoke", Map.merge(permission, role)}
          nil ->
            {:error, {:resource_not_found, "role", role}}
        end
      nil ->
        {:error, {:resource_not_found, "permission", permission}}
    end
  end
  def revoke(_req, [_, _]),
    do: {:error, :wrong_type}
  def revoke(_req, []),
    do: {:error, {:not_enough_args, 2}}
  def revoke(_req, [_]),
    do: {:error, {:not_enough_args, 2}}
  def revoke(_req, _),
    do: {:error, {:too_many_args, 2}}

end

defmodule Cog.Commands.Permission.Revoke do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "permission-revoke"

  alias Cog.Commands
  alias Cog.Models.{Permission, Role}
  alias Cog.Repository.{Permissions, Roles}

  @description "Revoke a permission from a role"

  @long_description """
  Unlike `create` and `delete`, you can grant any permission to a role, not
  just site permissions.
  """

  @arguments "<permission> <role>"

  @examples """
  Revoke a permission from a role:

    permission revoke site:foo dev
  """

  @output_description "Returns the serialized permission and role from which it was revoked"

  @output_example """
  [
    {
      "role": {
        "permissions": [],
        "name": "engineering",
        "id": "87ae871e-2835-4241-b6de-1fa43e554503"
      },
      "permission": {
        "name": "deploy",
        "id": "0f8c194b-7d4d-4723-8e9a-ca184f8d44fa",
        "bundle": "site"
      }
    }
  ]
  """

  permission "manage_permissions"
  permission "manage_roles"

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:permission-revoke must have #{Cog.Util.Misc.embedded_bundle}:manage_permissions"
  rule "when command is #{Cog.Util.Misc.embedded_bundle}:permission-revoke must have #{Cog.Util.Misc.embedded_bundle}:manage_roles"

  def handle_message(req = %{args: [permission, role]}, state) when is_binary(permission) and is_binary(role) do
    result = case Permissions.by_name(permission) do
      %Permission{}=permission ->
        case Roles.by_name(role) do
          %Role{}=role ->
            Roles.revoke(role, permission)
            role = Roles.by_name(role.name) # refetch
            permission = Cog.V1.PermissionView.render("show.json", %{permission: permission})
            role       = Cog.V1.RoleView.render("show.json", %{role: role})
            {:ok, "permission-revoke", Map.merge(permission, role)}
          nil ->
            {:error, {:resource_not_found, "role", role}}
        end
      nil ->
        {:error, {:resource_not_found, "permission", permission}}
    end

    case result do
      {:ok, template, data} ->
        {:reply, req.reply_to, template, data, state}
      {:error, err} ->
        {:error, req.reply_to, Commands.Permission.error(err), state}
    end
  end
  def handle_message(req = %{args: [_, _]}, state),
    do: {:error, req.reply_to, Commands.Permission.error(:wrong_type), state}
  def handle_message(req = %{args: args}, state) when length(args) < 2,
    do: {:error, req.reply_to, Commands.Permission.error({:not_enough_args, 2}), state}
  def handle_message(req, state),
    do: {:error, req.reply_to, Commands.Permission.error({:too_many_args, 2}), state}

end

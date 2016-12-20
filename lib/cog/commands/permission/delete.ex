defmodule Cog.Commands.Permission.Delete do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "permission-delete"

  alias Cog.Commands
  alias Cog.Models.Permission
  alias Cog.Repository.Permissions

  @description "Delete a site permission"

  @arguments "site:<name>"

  @examples """
  Delete a permission:

    permission delete site:foo
  """

  @output_description "Returns serialized permission that was just deleted"

  @output_example """
  [
    {
      "name": "deploy",
      "id": "e96a0fa8-e1d3-4b65-9c9a-6badc4f9b8df",
      "bundle": "site"
    }
  ]
  """

  permission "manage_permissions"

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:permission-delete must have #{Cog.Util.Misc.embedded_bundle}:manage_permissions"

  def handle_message(req = %{args: [<<"site:", _name :: binary>>=permission_name]}, state) do
    result = case Permissions.by_name(permission_name) do
      %Permission{}=permission ->
        Permissions.delete(permission)
        rendered = Cog.V1.PermissionView.render("show.json", %{permission: permission})
        {:ok, "permission-delete", rendered[:permission]}
      nil ->
        {:error, {:resource_not_found, "permission", permission_name}}
    end

    case result do
      {:ok, template, data} ->
        {:reply, req.reply_to, template, data, state}
      {:error, err} ->
        {:error, req.reply_to, Commands.Permission.error(err), state}
    end
  end
  def handle_message(req = %{args: [_invalid_permission]}, state),
    do: {:error, req.reply_to, Commands.Permission.error(:invalid_permission), state}
  def handle_message(req = %{args: []}, state),
    do: {:error, req.reply_to, Commands.Permission.error({:not_enough_args, 1}), state}
  def handle_message(req, state),
    do: {:error, req.reply_to, Commands.Permission.error({:too_many_args, 1}), state}
end

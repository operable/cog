defmodule Cog.Commands.Permission.Create do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "permission-create"

  alias Cog.Commands.Permission
  alias Cog.Repository.Permissions

  @description "Create a new site permission"

  @arguments "site:<name>"

  @examples """
  Creating a site permission:

    permission create site:foo
  """

  @output_description "Returns newly created serialized permission"

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

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:permission-create must have #{Cog.Util.Misc.embedded_bundle}:manage_permissions"

  def handle_message(req = %{args: [<<"site:", name :: binary>>]}, state) do
    result = case Permissions.create_permission(name) do
      {:ok, permission} ->
        rendered = Cog.V1.PermissionView.render("show.json", %{permission: permission})
        {:ok, "permission-create", rendered[:permission]}
      {:error, _}=error ->
        error
    end

    case result do
      {:ok, template, data} ->
        {:reply, req.reply_to, template, data, state}
      {:error, err} ->
        {:error, req.reply_to, Permission.error(err), state}
    end
  end
  def handle_message(req = %{args: [_invalid_permission]}, state),
    do: {:error, req.reply_to, Permission.error(:invalid_permission), state}
  def handle_message(req = %{args: []}, state),
    do: {:error, req.reply_to, Permission.error({:not_enough_args, 1}), state}
  def handle_message(req, state),
    do: {:error, req.reply_to, Permission.error({:too_many_args, 1}), state}

end

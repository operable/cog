defmodule Cog.Commands.Permission.Info do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "permission-info"

  alias Cog.Commands
  alias Cog.Models.Permission
  alias Cog.Repository.Permissions

  @description "Get detailed information about a permission"

  @arguments "<name>"

  @examples """
  Viewing a permission:

    permission info site:foo
  """

  @output_description "Returns serialized permission"

  @output_example """
  [
    {
      "name": "deploy",
      "id": "e96a0fa8-e1d3-4b65-9c9a-6badc4f9b8df",
      "bundle": "site"
    }
  ]
  """

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:permission-info must have #{Cog.Util.Misc.embedded_bundle}:manage_permissions"

  def handle_message(req = %{args: [name]}, state) when is_binary(name) do
    result = case Permissions.by_name(name) do
      %Permission{}=permission ->
        rendered = Cog.V1.PermissionView.render("show.json", %{permission: permission})
        {:ok, "permission-info", rendered[:permission]}
      nil ->
        {:error, {:resource_not_found, "permission", name}}
    end

    case result do
      {:ok, template, data} ->
        {:reply, req.reply_to, template, data, state}
      {:error, err} ->
        {:error, req.reply_to, Commands.Permission.error(err), state}
    end
  end
  def handle_message(req = %{args: [_invalid_permission]}, state),
    do: {:error, req.reply_to, Commands.Permission.error(:wrong_type), state}
  def handle_message(req = %{args: []}, state),
    do: {:error, req.reply_to, Commands.Permission.error({:not_enough_args, 1}), state}
  def handle_message(req, state),
    do: {:error, req.reply_to, Commands.Permission.error({:too_many_args, 1}), state}

end

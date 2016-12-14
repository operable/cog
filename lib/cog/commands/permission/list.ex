defmodule Cog.Commands.Permission.List do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "permission-list"

  alias Cog.Repository.Permissions

  @description "List all permissions"

  @output_description "Returns list of serialized permissions"

  @output_example """
  [
    {
      "name": "manage_commands",
      "id": "f29336f5-13c9-4cfc-88b4-fc28b752b7d8",
      "bundle": "operable"
    },
    {
      "name": "manage_groups",
      "id": "e9a88c10-7b99-4ec4-9917-d767397c2af4",
      "bundle": "operable"
    },
    {
      "name": "manage_permissions",
      "id": "9a002aad-6cda-4427-9a0a-d8da74f3912d",
      "bundle": "operable"
    }
  ]
  """

  permission "manage_permissions"

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:permission-list must have #{Cog.Util.Misc.embedded_bundle}:manage_permissions"

  def handle_message(req, state) do
    rendered = Cog.V1.PermissionView.render("index.json", %{permissions: Permissions.all})
    {:reply, req.reply_to, "permission-list", rendered[:permissions], state}
  end
end

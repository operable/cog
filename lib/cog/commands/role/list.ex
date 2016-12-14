defmodule Cog.Commands.Role.List do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "role-list"

  alias Cog.Repository.Roles
  alias Cog.V1.RoleView

  @description "List all roles"

  @output_description "Returns a list of serialized roles"

  @output_example """
  [
    {
      "permissions": [
        {
          "name": "manage_commands",
          "id": "b4ecc764-18af-4b68-b465-5d27e8e9602b",
          "bundle": "operable"
        },
        {
          "name": "manage_groups",
          "id": "14df8f80-006d-4875-9a4b-a092e2574933",
          "bundle": "operable"
        },
        {
          "name": "manage_permissions",
          "id": "e4f79b25-77da-4b0e-a1ee-dbd4e7b166e4",
          "bundle": "operable"
        },
        {
          "name": "manage_relays",
          "id": "f18ec6c2-669f-4ccc-a851-32fbd9e7f94c",
          "bundle": "operable"
        },
        {
          "name": "manage_roles",
          "id": "dac77dcc-e3ad-423d-bc15-bc54f63c765e",
          "bundle": "operable"
        },
        {
          "name": "manage_triggers",
          "id": "d3a04a50-f4c6-47c8-9270-a83399eefd48",
          "bundle": "operable"
        },
        {
          "name": "manage_users",
          "id": "a598628c-c2d8-4ace-9abc-29467e35f5e0",
          "bundle": "operable"
        }
      ],
      "name": "cog-admin",
      "id": "87235760-01cf-41ed-bbce-5db97dc54f69"
    },
    {
      "permissions": [],
      "name": "admin",
      "id": "b711d91a-dcbe-4adc-862f-ea9144438955"
    }
  ]
  """

  permission "manage_roles"

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:role-list must have #{Cog.Util.Misc.embedded_bundle}:manage_roles"

  def handle_message(req, state) do
    roles = Roles.all
    rendered = RoleView.render("index.json", %{roles: roles})
    {:reply, req.reply_to, "role-list", rendered[:roles], state}
  end
end

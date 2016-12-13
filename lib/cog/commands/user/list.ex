defmodule Cog.Commands.User.List do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "user-list"

  alias Cog.Repository.Users

  @description "List all users."

  @output_description "Returns a list of users; their groups, roles, permissions and chat handles."

  @output_example """
  [
    {
      "username": "Cog",
      "last_name": "McCog",
      "id": "00000000-0000-0000-0000-000000000000",
      "groups": [
        {
          "roles": [
            {
              "permissions": [
                {
                  "name": "manage_users",
                  "id": "00000000-0000-0000-0000-000000000000",
                  "bundle": "operable"
                },
              ],
              "name": "cog-admin",
              "id": "00000000-0000-0000-0000-000000000000"
            }
          ],
          "name": "cog-admin",
          "id": "00000000-0000-0000-0000-000000000000"
        }
      ],
      "first_name": "Cog",
      "email_address": "cog@localhost",
      "chat_handles": [
        {
          "username": "admin",
          "id": "00000000-0000-0000-0000-000000000000",
          "handle": "cog",
          "chat_provider": {
            "name": "slack"
          }
        }
      ]
    }
  ]
  """
  permission "manage_users"

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:user-list must have #{Cog.Util.Misc.embedded_bundle}:manage_users"

  def handle_message(req, state) do
    rendered = Cog.V1.UserView.render("index.json", %{users: Users.all})
    {:reply, req.reply_to, "user-list", rendered[:users], state}
  end

end

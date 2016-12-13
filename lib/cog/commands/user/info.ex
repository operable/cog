defmodule Cog.Commands.User.Info do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "user-info"

  alias Cog.Repository.Users
  require Cog.Commands.Helpers, as: Helpers

  @description "Show detailed information about a specific user."

  @arguments "<username>"

  @output_description "Returns a single user; their groups, roles, permissions and chat handles."

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

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:user-info must have #{Cog.Util.Misc.embedded_bundle}:manage_users"

  def handle_message(req, state) do
    results = with {:ok, [user_name]} <- Helpers.get_args(req.args, 1) do
      case Users.by_username(user_name) do
        {:error, :not_found} ->
          {:error, {:resource_not_found, "user", user_name}}
        {:ok, user} ->
          rendered = Cog.V1.UserView.render("show.json", %{user: user})
          {:ok, rendered[:user]}
      end
    end

    case results do
      {:ok, data} ->
        {:reply, req.reply_to, "user-info", data, state}
      {:error, error} ->
        {:error, req.reply_to, Helpers.error(error), state}
    end
  end

end

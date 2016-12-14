defmodule Cog.Commands.User.AttachHandle do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "user-attach-handle"

  alias Cog.Repository.Users
  alias Cog.Repository.ChatHandles

  require Cog.Commands.Helpers, as: Helpers

  @description "Attach a chat handle for this chat provider with an existing Cog user."

  @arguments "<username> <handle>"

  @output_description "Returns the user with their attached handle."

  @output_example """
  [
    {
      "username": "bob",
      "id": "00000000-0000-0000-0000-000000000000",
      "handle": "mrbob",
      "chat_provider": {
        "name": "slack"
      }
    }
  ]
  """

  permission "manage_users"

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:user-attach-handle must have #{Cog.Util.Misc.embedded_bundle}:manage_users"

  def handle_message(req, state) do
    result = with {:ok, [user_name, handle]} <- Helpers.get_args(req.args, 2) do
      case Users.by_username(user_name) do
        {:error, :not_found} ->
          {:error, {:resource_not_found, "user", user_name}}
        {:ok, user} ->
          provider_name = req.requestor.provider
          case ChatHandles.set_handle(user, provider_name, handle) do
            {:ok, handle} ->
              {:ok, Cog.V1.ChatHandleView.render("show.json", %{chat_handle: handle})}
            {:error, error} ->
              {:error, error}
          end
      end
    end

    case result do
      {:ok, data} ->
        {:reply, req.reply_to, "user-attach-handle", data, state}
      {:error, error} ->
        {:error, req.reply_to, Helpers.error(error), state}
    end
  end

end

defmodule Cog.Commands.User.DetachHandle do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "user-detach-handle"

  alias Cog.Repository.Users
  alias Cog.Repository.ChatHandles

  require Cog.Commands.Helpers, as: Helpers

  @description "Sever association between a chat handle and a user"

  @long_description """
  Detach the chat handle for this chat provider from an existing Cog user.

  After running this, the user will not be able to interact with Cog via chat.
  """

  @arguments "<username>"

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:user-detach-handle must have #{Cog.Util.Misc.embedded_bundle}:manage_users"

  def handle_message(req, state) do
    result = with {:ok, [user_name]} <- Helpers.get_args(req.args, 1) do
      case Users.by_username(user_name) do
        {:error, :not_found} ->
          {:error, {:resource_not_found, "user", user_name}}
        {:ok, user} ->
          provider_name = req.requestor.provider
          :ok = ChatHandles.remove_handle(user, provider_name)
          {:ok, %{"username" => user.username, "chat_provider" => %{"name" => provider_name}}}
      end
    end

    case result do
      {:ok, data} ->
        {:reply, req.reply_to, "user-detach-handle", data, state}
      {:error, error} ->
        {:error, req.reply_to, Helpers.error(error), state}
    end
  end

end

defmodule Cog.Commands.User.DetachHandle do
  alias Cog.Repository.Users
  alias Cog.Repository.ChatHandles

  require Cog.Commands.Helpers, as: Helpers

  Helpers.usage """
  Detach the chat handle for this chat provider from an existing Cog user.

  After running this, the user will not be able to interact with Cog via chat.

  USAGE
    user detach-handle [FLAGS] <username>

  ARGS
    username   The name of a user

  FLAGS
    -h, --help  Display this usage info
  """

  def detach(%{options: %{"help" => true}}, _args) do
    show_usage
  end
  def detach(req, [user_name]) do
    case Users.by_username(user_name) do
      {:error, :not_found} ->
        {:error, {:resource_not_found, "user", user_name}}
      {:ok, user} ->
        provider_name = req.requestor["provider"]
        :ok = ChatHandles.remove_handle(user, provider_name)
        {:ok, "user-detach-handle", %{"username" => user.username,
                                      "chat_provider" => %{"name" => provider_name}}}
    end
  end
  def detach(_, []),
    do: {:error, {:not_enough_args, 1}}
  def detach(_, _),
    do: {:error, {:too_many_args, 1}}

end

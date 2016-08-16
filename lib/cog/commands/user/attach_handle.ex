defmodule Cog.Commands.User.AttachHandle do
  alias Cog.Repository.Users
  alias Cog.Repository.ChatHandles

  require Cog.Commands.Helpers, as: Helpers

  Helpers.usage """
  Attach a chat handle for this chat provider with an existing Cog user.

  USAGE
    user attach-handle [FLAGS] <username> <handle>

  ARGS
    username   The name of a user
    handle     The user's chat handle

  FLAGS
    -h, --help  Display this usage info
  """

  def attach(%{options: %{"help" => true}}, _args) do
    show_usage
  end
  def attach(req, [user_name, handle]) do
    case Users.by_username(user_name) do
      {:error, :not_found} ->
        {:error, {:resource_not_found, "user", user_name}}
      {:ok, user} ->
        provider_name = req.requestor["provider"]
        case ChatHandles.set_handle(user, provider_name, handle) do
          {:ok, handle} ->
            {:ok, "user-attach-handle", Cog.V1.ChatHandleView.render("show.json", %{chat_handle: handle})}
          {:error, error} ->
            {:error, error}
        end
    end
  end
  def attach(_, []),
    do: {:error, {:not_enough_args, 2}}
  def attach(_, [_]),
    do: {:error, {:not_enough_args, 2}}
  def attach(_, _),
    do: {:error, {:too_many_args, 2}}

end

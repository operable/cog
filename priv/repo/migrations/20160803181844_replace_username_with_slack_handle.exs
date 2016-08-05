defmodule Cog.Repo.Migrations.ReplaceUsernameWithSlackHandle do
  use Ecto.Migration
  alias Cog.Repo
  alias Cog.Models.User

  def change do
    users = User
    |> Repo.all
    |> Repo.preload([chat_handles: :chat_provider])

    Enum.each(users, fn user ->
      username_is_email = user.username == user.email_address

      slack_handle = Enum.find_value(user.chat_handles, fn chat_handle ->
        case chat_handle.chat_provider.name do
          "slack" ->
            chat_handle.handle
          _ ->
            nil
        end
      end)

      slack_handle = slack_handle || user.username

      params = case username_is_email do
        false ->
          %{}
        true ->
          %{"username" => slack_handle}
      end

      Repo.update!(User.changeset(user, params))
    end)
  end
end

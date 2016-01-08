defmodule Cog.Adapters.Slack.Helpers do
  alias Cog.Adapters.Slack
  alias Cog.Assertions
  alias Cog.Models.User

  @bot_handle "deckard"
  @room "ci_bot_testing"
  @interval 1000 # 1 second
  @timeout 120000 # 2 minutes

  def send_message(%User{username: username}, message) do
    {:ok, %{id: id}} = Slack.API.lookup_user(handle: @bot_handle)
    message = String.replace(message, "@#{@bot_handle}", "<@#{id}>")
    {:ok, message} = Slack.API.send_message(room: "#" <> @room, text: message, as_user: username)
    message
  end

  def assert_response(message, [after: %{"ts" => ts}]) do
    :timer.sleep(@interval)

    last_message_func = fn ->
      {:ok, last_message} = Slack.API.retrieve_last_message(room: @room, oldest: ts)
      last_message
    end

    Assertions.polling_assert(message, last_message_func, @interval, @timeout)
  end
end

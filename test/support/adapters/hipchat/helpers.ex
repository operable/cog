defmodule Cog.Adapters.Hipchat.Helpers do
  alias Cog.Adapters.Hipchat
  alias Cog.Assertions
  alias Cog.Models.User

  @bot_handle "deckard"
  @room "ci_bot_testing"
  @interval 5000 # 5 seconds
  @timeout 120000 # 2 minutes

  def send_message(%User{username: _username}, message) do
    Hipchat.message(@room, message)
  end

  def assert_response(message, [after: %{"id" => id}]) do
    :timer.sleep(@interval)

    last_message_func = fn ->
      Hipchat.API.retrieve_last_message(@room, id)
    end

    Assertions.polling_assert(message, last_message_func, @interval, @timeout)
  end
end

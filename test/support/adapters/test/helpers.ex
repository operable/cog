defmodule Cog.Adapters.Test.Helpers do
  require Logger
  alias Cog.Snoop

  @here "TEST_ADAPTER_HERE"

  # Wait a total of @tries x @wait ms to receive a single response
  # from the test adapter
  @tries 60
  @wait 50 # ms

  # Convenience for sending a message and receiving the single
  # response back to where it was sent
  def send_message(user, text) do
    {:ok, snoop} = Cog.Snoop.adapter_traffic
    send_message(user, @here, text)
    loop_until_received(snoop, @tries)
  end

  defp loop_until_received(_, 0),
    do: raise "Didn't get a message!"
  defp loop_until_received(snoop, count) do
    :timer.sleep(@wait)
    responses = snoop
    |> Snoop.messages
    |> Snoop.to_endpoint("send")
    |> Snoop.to_provider("test")
    |> Snoop.targeted_to(@here)
    |> Snoop.bare_messages

    case responses do
      [] ->
        loop_until_received(snoop, count - 1)
      _ ->
        # TODO: temporary (?)
        # There are places that use atom keys; this lets me update the
        # test infrastructure without having to mess with the tests
        # themselves
        Enum.map(responses,
          fn(response) ->
            if is_binary(response) do
              # String responses are generally error messages
              response
            else
              response
              |> Poison.encode!
              |> Poison.decode!(keys: :atoms)
            end
          end)
    end
  end

  def send_message(%Cog.Models.User{}=user, here_id, "@bot: " <> message) do
    Cog.Chat.TestProvider.chat_message(user, here_id, "@bot: " <> message)
  end
end

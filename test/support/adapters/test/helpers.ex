defmodule Cog.Adapters.Test.Helpers do
  require Logger
  alias Cog.Snoop

  @here "TEST_ADAPTER_HERE"

  # Convenience for sending a message and receiving the single
  # response back to where it was sent
  def send_message(user, text) do
    {:ok, snoop} = Cog.Snoop.adapter_traffic
    send_message(user, @here, text)

    # SINGLE MESSAGE!!!
    [message] = Snoop.loop_until_received(snoop, provider: "test", target: @here)
    message
  end

  # For now, we need to ensure that each pipeline we execute pipes
  # into the `raw` command, which will allow us to reverse-engineer
  # the raw data that came out of the pipeline so we can make
  # assertions against it.
  def send_message(%Cog.Models.User{}=user, here_id, "@bot: " <> message) do
    message = case Regex.run(~r/(.*[^*])(\*?> .*)/, message, capture: :all_but_first) do
      [pipeline, destinations] ->
        maybe_append_raw(pipeline) <> " #{destinations}"
      nil ->
        maybe_append_raw(message)
    end
    Cog.Chat.Test.Provider.chat_message(user, here_id, "@bot: " <> message)
  end

  ########################################################################

  defp maybe_append_raw(pipeline) do
    if String.ends_with?(pipeline, " | raw") do
      pipeline
    else
      pipeline <> " | raw"
    end
  end

end

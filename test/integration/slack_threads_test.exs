defmodule Integration.SlackThreadsTest do
  use ExUnit.Case

  setup_all do
    slack_config = Application.get_env(:cog, Cog.Chat.Slack.Provider)
    slack_config_with_threads = Keyword.put(slack_config, :enable_threaded_response, true)
    Application.put_env(:cog, Cog.Chat.Slack.Provider, slack_config_with_threads)

    {:ok, %{slack_config: slack_config}}
  end

  use Cog.Test.Support.ProviderCase, provider: :slack, force: true

  setup_all %{slack_config: slack_config} do
    on_exit(fn ->
      Application.put_env(:cog, Cog.Chat.Slack.Provider, slack_config)
    end)
  end

  @user "botci"
  @bot "deckard"
  @ci_room "ci_bot_testing"

  setup do
    @user |> user |> with_chat_handle_for("slack")
    {:ok, client} = ChatClient.new()
    {:ok, %{client: client}}
  end

  test "messages are threaded based on the original message", %{client: client} do
    {:ok, reply} = ChatClient.chat_wait!(
      client, [room: @ci_room,
               message: "@#{@bot}: operable:echo messages are threaded based on the original message",
               reply_from: @bot])
    refute reply.thread_ts == nil
  end

  test "messages redirected to another room or dm are not threaded", %{client: client} do
    {:ok, reply} = ChatClient.chat_wait!(
      client, [room: @ci_room,
               message: "@#{@bot}: operable:echo messages redirected to another room or dm are not threaded > #ci_bot_redirect_tests",
               reply_from: @bot])
    assert reply.thread_ts == nil
  end
end

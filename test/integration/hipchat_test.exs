defmodule Integration.HipChatTest do
  use Cog.Test.Support.ProviderCase, provider: :hipchat

  @user "botci"

  @bot "deckard"
  @bot_name "Rich Deckard"

  @ci_room "ci_bot_testing"
  @timeout 30000

  setup do
    # The user always interacts with the bot via the `@user` account
    # (see above). Our helper functions set up a user with the same
    # Cog username and Slack handle
    user = user(@user)
    |> with_chat_handle_for("hipchat")
    {:ok, client} = ChatClient.new()
    {:ok, %{user: user, client: client}}
  end

  test "running the st-echo command", %{user: user, client: client} do
    user |> with_permission("operable:st-echo")
    {:ok, reply} = ChatClient.chat_wait!(client, [room: @ci_room, message: "@#{@bot} operable:st-echo test", reply_from: @bot_name, timeout: @timeout])
    assert reply.text == "test"
  end

  test "running the st-echo command without permission", %{client: client} do
    message = "@#{@bot}: operable:st-echo test"
    {:ok, reply} = ChatClient.chat_wait!(client, [room: @ci_room, message: message,
                                                  reply_from: @bot_name, timeout: @timeout])
    assert String.contains?(reply.text, "<strong>Pipeline:</strong> operable:st-echo test")
    assert String.contains?(reply.text, "You will need at least one of the following permissions to run this command: " <>
      "'operable:st-echo'")
    assert reply.location.type == :channel
    assert reply.location.name == @ci_room
  end

  test "running commands in a pipeline", %{user: user, client: client} do
    user
    |> with_permission("operable:echo")
    |> with_permission("operable:thorn")

    message = "@#{@bot}: seed '[{\"test\": \"blah\"}]' | echo $test"
    {:ok, reply} = ChatClient.chat_wait!(client, [room: @ci_room, message: message, reply_from: @bot_name, timeout: @timeout])
    assert reply.text == "blah"
    assert reply.location.type == :channel
    assert reply.location.name == @ci_room
  end

  test "running commands in a pipeline without permission", %{user: user, client: client} do
    user |> with_permission("operable:st-echo")

    message = "@#{@bot}: operable:st-echo \"this is a test\" | operable:st-thorn $body"
    {:ok, reply} = ChatClient.chat_wait!(client, [room: @ci_room, message: message, reply_from: @bot_name, timeout: @timeout])
    assert String.contains?(reply.text, "<strong>Pipeline:</strong> operable:st-echo \"this is a test\" | operable:st-thorn $body")
    assert String.contains?(reply.text, "You will need at least one of the following permissions to run this command: " <>
      "'operable:st-thorn'.")
    assert reply.location.type == :channel
    assert reply.location.name == @ci_room
  end

  test "redirecting to a private channel", %{user: user, client: client} do
    user |> with_permission("operable:echo")
    time = "#{System.os_time()}"
    private_channel = "private_ci_testing"
    message = "@#{@bot}: operable:echo #{time} > #{private_channel}"
    {:ok, reply} = ChatClient.chat_wait!(client, [room: @ci_room, message: message, reply_from: @bot_name, timeout: @timeout])
    assert reply.location.type == :channel
    assert reply.location.name == private_channel
    assert reply.text == time
  end

 test "redirecting to 'here'", %{user: user, client: client} do
    user |> with_permission("operable:echo")
    message = "@#{@bot}: operable:echo blah > here"
    {:ok, reply} = ChatClient.chat_wait!(client, [room: @ci_room, message: message, reply_from: @bot_name, timeout: @timeout])
    assert reply.text == "blah"
    assert reply.location.type == :channel
    assert reply.location.name == @ci_room
  end

  test "redirecting to 'me'", %{user: user, client: client} do
    user |> with_permission("operable:echo")

    message = "@#{@bot}: operable:echo blah > me"
    {:ok, reply} = ChatClient.chat_wait!(client, [room: @ci_room, message: message, reply_from: @bot_name, timeout: @timeout])
    assert reply.location.type == :im
    assert reply.text == "blah"
  end

  test "redirecting to a specific user", %{user: user, client: client} do
    user |> with_permission("operable:echo")
    message = "@#{@bot}: operable:echo blah > #{@user}"
    {:ok, reply} = ChatClient.chat_wait!(client, [room: @ci_room, message: message, reply_from: @bot_name, timeout: @timeout])
    assert reply.text == "blah"
    assert reply.location.type == :im
  end

  test "redirecting to another channel", %{user: user, client: client} do
    user |> with_permission("operable:echo")
    redirect_channel = "ci_bot_redirect_tests"
    message = "@#{@bot}: operable:echo blah > #{redirect_channel}"
    {:ok, reply} = ChatClient.chat_wait!(client, [room: @ci_room, message: message, reply_from: @bot_name, timeout: @timeout])
    assert reply.location.type == :channel
    assert reply.location.name == redirect_channel
    assert reply.text == "blah"
  end

end

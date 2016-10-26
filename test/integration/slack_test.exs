defmodule Integration.SlackTest do
  use Cog.Test.Support.ProviderCase, provider: :slack

  @user "botci"

  @bot "deckard"

  @ci_room "ci_bot_testing"

  setup do
    # Wait random 1-3 second interval to avoid being throttled by Slack's API
    interval = :rand.uniform(3) * 1000
    :timer.sleep(interval)

    # The user always interacts with the bot via the `@user` account
    # (see above). Our helper functions set up a user with the same
    # Cog username and Slack handle
    user = user(@user)
    |> with_chat_handle_for("slack")

    {:ok, client} = ChatClient.new()
    {:ok, %{user: user, client: client}}
  end

  test "running the st-echo command", %{user: user, client: client} do
    user |> with_permission("operable:st-echo")
    {:ok, reply} = ChatClient.chat_wait!(client, [room: @ci_room, message: "@#{@bot} operable:st-echo test", reply_from: @bot])
    assert reply.text == "test"
  end

  test "running the st-echo command without permission", %{client: client} do
    message = "@#{@bot}: operable:st-echo test"
    {:ok, reply} = ChatClient.chat_wait!(client, [room: @ci_room, message: message,
                                                   reply_from: @bot])
    expected = """
    The pipeline failed executing the command:

    ```operable:st-echo test```

    The specific error was:

    ```Sorry, you aren't allowed to execute 'operable:st-echo test' :(
     You will need at least one of the following permissions to run this command: 'operable:st-echo'.```
    """ |> String.strip
    assert reply.text == expected
    assert reply.location.type == :channel
    assert reply.location.name == @ci_room
  end

  test "running commands in a pipeline", %{user: user, client: client} do
    user
    |> with_permission("operable:echo")
    |> with_permission("operable:thorn")

    message = "@#{@bot}: seed '[{\"test\": \"blah\"}]' | echo $test"
    {:ok, reply} = ChatClient.chat_wait!(client, [room: @ci_room, message: message, reply_from: @bot])
    assert reply.text == "blah"
    assert reply.location.type == :channel
    assert reply.location.name == @ci_room
  end

  test "running commands in a pipeline without permission", %{user: user, client: client} do
    user |> with_permission("operable:st-echo")

    message = "@#{@bot}: operable:st-echo \"this is a test\" | operable:st-thorn $body"
    {:ok, reply} = ChatClient.chat_wait!(client, [room: @ci_room, message: message, reply_from: @bot])
    expected = """
    The pipeline failed executing the command:

    ```operable:st-thorn $body```

    The specific error was:

    ```Sorry, you aren't allowed to execute 'operable:st-thorn $body' :(
      You will need at least one of the following permissions to run this command: 'operable:st-thorn'.```
     """ |> String.strip
    assert reply.text == expected
    assert reply.location.type == :channel
    assert reply.location.name == @ci_room
  end

  test "sending a message to a group", %{user: user, client: client} do
    user |> with_permission("operable:echo")
    private_group = "group_ci_bot_testing"

    message = "@#{@bot}: operable:echo blah"
    {:ok, reply} = ChatClient.chat_wait!(client, [room: private_group, message: message, reply_from: @bot])
    assert reply.text == "blah"
    assert reply.location.type == :group
    assert reply.location.name == private_group
  end

  test "redirecting from a private channel", %{user: user, client: client} do
    user |> with_permission("operable:echo")
    private_channel = "group_ci_bot_testing"
    message = "@#{@bot}: operable:echo blah > ##{private_channel}"
    {:ok, reply} = ChatClient.chat_wait!(client, [room: @ci_room, message: message, reply_from: @bot])
    assert reply.location.type == :group
    assert reply.location.name == private_channel
    assert reply.text == "blah"
  end

  test "redirecting to a private channel", %{user: user, client: client} do
    user |> with_permission("operable:echo")
    time = "#{System.os_time()}"
    private_channel = "group_ci_bot_testing"
    message = "@#{@bot}: operable:echo #{time} > ##{private_channel}"
    {:ok, reply} = ChatClient.chat_wait!(client, [room: @ci_room, message: message, reply_from: @bot])
    assert reply.location.type == :group
    assert reply.location.name == private_channel
    assert reply.text == time
  end

 test "redirecting to 'here'", %{user: user, client: client} do
    user |> with_permission("operable:echo")
    message = "@#{@bot}: operable:echo blah > here"
    {:ok, reply} = ChatClient.chat_wait!(client, [room: @ci_room, message: message, reply_from: @bot])
    assert reply.text == "blah"
    assert reply.location.type == :channel
    assert reply.location.name == @ci_room
  end

  test "redirecting to 'me'", %{user: user, client: client} do
    user |> with_permission("operable:echo")

    message = "@#{@bot}: operable:echo blah > me"
    {:ok, reply} = ChatClient.chat_wait!(client, [room: @ci_room, message: message, reply_from: @bot])
    assert reply.location.type == :im
    # Since Cog responds when direct messaging it we have to assert
    # that both our marker text and message test exist.
    #assert_response "here\nblah", [after: marker, count: 2], "@#{@user}"
  end

  test "redirecting to a specific user", %{user: user, client: client} do
    user |> with_permission("operable:echo")
    message = "@#{@bot}: operable:echo blah > @#{@user}"
    {:ok, reply} = ChatClient.chat_wait!(client, [room: @ci_room, message: message, reply_from: @bot])
    assert reply.text == "blah"
    assert reply.location.type == :im
  end

  test "redirecting to another channel", %{user: user, client: client} do
    user |> with_permission("operable:echo")
    redirect_channel = "ci_bot_redirect_tests"
    message = "@#{@bot}: operable:echo blah > ##{redirect_channel}"
    {:ok, reply} = ChatClient.chat_wait!(client, [room: @ci_room, message: message, reply_from: @bot])
    assert reply.location.type == :channel
    assert reply.location.name == redirect_channel
    assert reply.text == "blah"
  end

end

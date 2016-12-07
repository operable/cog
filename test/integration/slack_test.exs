defmodule Integration.SlackTest do
  use Cog.Test.Support.ProviderCase, provider: :slack

  @user "botci"

  @bot "deckard"
  @ci_room "ci_bot_testing"
  @redirect_channel "ci_bot_redirect_tests"
  @private_group "group_ci_bot_testing"

  setup do
    # The user always interacts with the bot via the `@user` account
    # (see above). Our helper functions set up a user with the same
    # Cog username and Slack handle
    user = user(@user)
    |> with_chat_handle_for("slack")

    :timer.sleep(1_500)
    {:ok, client} = ChatClient.new()
    {:ok, %{client: client, user: user}}
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
    ```Sorry, you aren't allowed to execute 'operable:st-echo test'.
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
    ```Sorry, you aren't allowed to execute 'operable:st-thorn $body'.
     You will need at least one of the following permissions to run this command: 'operable:st-thorn'.```
     """ |> String.strip
    assert reply.text == expected
    assert reply.location.type == :channel
    assert reply.location.name == @ci_room
  end

  test "sending a message to a group", %{user: user, client: client} do
    user |> with_permission("operable:echo")

    message = "@#{@bot}: operable:echo blah"
    {:ok, reply} = ChatClient.chat_wait!(client, [room: @private_group, message: message, reply_from: @bot])
    assert reply.text == "blah"
    assert reply.location.type == :group
    assert reply.location.name == @private_group
  end

  test "redirecting from a private channel", %{user: user, client: client} do
    user |> with_permission("operable:echo")
    message = "@#{@bot}: operable:echo blah > ##{@private_group}"
    {:ok, reply} = ChatClient.chat_wait!(client, [room: @ci_room, message: message, reply_from: @bot])
    assert reply.location.type == :group
    assert reply.location.name == @private_group
    assert reply.text == "blah"
  end

  test "redirecting to a private channel", %{user: user, client: client} do
    user |> with_permission("operable:echo")
    time = "#{System.os_time()}"
    message = "@#{@bot}: operable:echo #{time} > ##{@private_group}"
    {:ok, reply} = ChatClient.chat_wait!(client, [room: @ci_room, message: message, reply_from: @bot])
    assert reply.location.type == :group
    assert reply.location.name == @private_group
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
    # assert_response "here\nblah", [after: marker, count: 2], "@#{@user}"
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
    message = "@#{@bot}: operable:echo blah > ##{@redirect_channel}"
    {:ok, reply} = ChatClient.chat_wait!(client, [room: @ci_room, message: message, reply_from: @bot])
    assert reply.location.type == :channel
    assert reply.location.name == @redirect_channel
    assert reply.text == "blah"
  end

  @tag :skip
  test "formatting with unicode present", %{user: user, client: client} do
    user |> with_permission("operable:echo")

    # We use a different URL each time because we otherwise end up
    # having to deal with messages from Slack saying "we didn't unfurl
    # this for you since we already did in the past hour" when we run
    # lots of tests in a row.
    #
    # (I think a user or channel mention would also suffice, since the
    # regression we're guarding against involves improperly processing
    # Slack's links.)
    url = "https://test.operable.io/#{System.system_time(:milliseconds)}"
    {:ok, reply} = ChatClient.chat_wait!(client, [room: @ci_room, message: "@#{@bot} operable:echo \"ϻ #{url}\"", reply_from: @bot])
    assert reply.text == "ϻ <#{url}>"
  end
end

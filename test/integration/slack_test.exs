defmodule Integration.SlackTest do
  use Cog.Test.Support.ProviderCase, provider: :slack

  @user "botci"

  @bot "deckard"
  @ci_room "ci_bot_testing"
  @redirect_channel "ci_bot_redirect_tests"
  @private_group "group_ci_bot_testing"

  setup_all do
    {:ok, client} = ChatClient.new()
    {:ok, %{client: client}}
  end

  setup context do
    # The user always interacts with the bot via the `@user` account
    # (see above). Our helper functions set up a user with the same
    # Cog username and Slack handle
    user = user(@user)
    |> with_chat_handle_for("slack")

    {:ok, Map.put(context, :user, user)}
  end

  test "running the st-echo command", %{user: user, client: client} do
    user |> with_permission("operable:st-echo")
    {:ok, reply} = ChatClient.chat_wait!(client,
                                         [room: @ci_room,
                                          message: "@#{@bot}: operable:st-echo 'running the st-echo command'",
                                          reply_from: @bot])
    assert reply.text == "running the st-echo command"
  end

  test "running the st-echo command without permission", %{client: client} do
    message = "@#{@bot}: operable:st-echo 'running the st-echo command without permission'"
    {:ok, reply} = ChatClient.chat_wait!(client, [room: @ci_room, message: message,
                                                  reply_from: @bot])
    expected = """
    ```Sorry, you aren't allowed to execute 'operable:st-echo 'running the st-echo command without permission''.
    You will need at least one of the following permissions to run this command: 'operable:st-echo'.```
    """ |> String.strip

    assert reply.text == expected
    assert reply.location.type == :channel
    assert reply.location.name == @ci_room
  end

  test "running commands in a pipeline", %{user: user, client: client} do
    role = role("testrole")
           |> with_permission("operable:echo")
           |> with_permission("operable:thorn")
    group("testgroup")
    |> add_to_group(role)
    |> add_to_group(user)

    message = "@#{@bot}: seed '[{\"test\": \"running commands in a pipeline\"}]' | echo $test"
    {:ok, reply} = ChatClient.chat_wait!(client, [room: @ci_room, message: message, reply_from: @bot])
    assert reply.text == "running commands in a pipeline"
    assert reply.location.type == :channel
    assert reply.location.name == @ci_room
  end

  test "running commands in a pipeline without permission", %{user: user, client: client} do
    user |> with_permission("operable:st-echo")

    message = "@#{@bot}: operable:st-echo \"running commands in a pipeline without permission\" | operable:st-thorn $body"
    {:ok, reply} = ChatClient.chat_wait!(client, [room: @ci_room, message: message, reply_from: @bot])
    expected = """
    ```Sorry, you aren't allowed to execute 'operable:st-thorn $body'.
     You will need at least one of the following permissions to run this command: 'operable:st-thorn'.```
     """ |> String.strip
    assert reply.text == expected
    assert reply.location.type == :channel
    assert reply.location.name == @ci_room
  end

  test "sending a message to a group", %{client: client} do
    message = "@#{@bot}: operable:echo sending a message to a group"
    {:ok, reply} = ChatClient.chat_wait!(client, [room: @private_group, message: message, reply_from: @bot])
    assert reply.location.type == :group
    assert reply.location.name == @private_group
    assert reply.text == "sending a message to a group"
  end

  test "redirecting to a private channel", %{client: client} do
    message = "@#{@bot}: operable:echo redirecting to a private channel > ##{@private_group}"
    {:ok, reply} = ChatClient.chat_wait!(client, [room: @ci_room, message: message, reply_from: @bot])
    assert reply.location.type == :group
    assert reply.location.name == @private_group
    assert reply.text == "redirecting to a private channel"
  end

 test "redirecting to 'here'", %{client: client} do
    message = "@#{@bot}: operable:echo redirecting to here > here"
    {:ok, reply} = ChatClient.chat_wait!(client, [room: @ci_room, message: message, reply_from: @bot])
    assert reply.text == "redirecting to here"
    assert reply.location.type == :channel
    assert reply.location.name == @ci_room
  end

  test "redirecting to 'me'", %{client: client} do
    message = "@#{@bot}: operable:echo redirecting to me > me"
    {:ok, reply} = ChatClient.chat_wait!(client, [room: @ci_room, message: message, reply_from: @bot])
    assert reply.location.type == :im
    # Since Cog responds when direct messaging it we have to assert
    # that both our marker text and message test exist.
    # assert_response "here\nblah", [after: marker, count: 2], "@#{@user}"
  end

  test "redirecting to a specific user", %{client: client} do
    message = "@#{@bot}: operable:echo redirecting to a specific user > @#{@user}"
    {:ok, reply} = ChatClient.chat_wait!(client, [room: @ci_room, message: message, reply_from: @bot])
    assert reply.text == "redirecting to a specific user"
    assert reply.location.type == :im
  end

  test "redirecting to another channel", %{client: client} do
    message = "@#{@bot}: operable:echo redirecting to another channel > ##{@redirect_channel}"
    {:ok, reply} = ChatClient.chat_wait!(client, [room: @ci_room, message: message, reply_from: @bot])
    assert reply.location.type == :channel
    assert reply.location.name == @redirect_channel
    assert reply.text == "redirecting to another channel"
  end

  @tag :skip
  test "formatting with unicode present", %{client: client} do
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

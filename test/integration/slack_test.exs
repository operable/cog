defmodule Integration.SlackTest do
  use Cog.AdapterCase, adapter: "slack"

  @moduletag :slack

  # Name of the Slack user we'll be interacting with the bot as
  @user "botci"

  # Name of the bot we'll be operating as
  @bot "deckard"

  setup do
    # The user always interacts with the bot via the `@user` account
    # (see above). Our helper functions set up a user with the same
    # Cog username and Slack handle
    user = user(@user)
    |> with_chat_handle_for("slack")

    {:ok, %{user: user}}
  end

  test "editing a command", %{user: user} do
    user |> with_permission("operable:st-echo")

    message = send_edited_message("@#{@bot}: operable:st-echo test")
    assert_edited_response "@#{@user} Executing edited command 'operable:st-echo test'\ntest", after: message
  end

  test "running the st-echo command", %{user: user} do
    user |> with_permission("operable:st-echo")

    message = send_message("@#{@bot}: operable:st-echo test")
    assert_response "test", after: message
  end

  test "running the st-echo command without permission" do
    message = send_message("@#{@bot}: operable:st-echo test")
    assert_response_contains "Sorry, you aren't allowed to execute 'operable:st-echo test' :(\n You will need the 'operable:st-echo' permission to run this command.", after: message
  end

  test "running commands in a pipeline", %{user: user} do
    user
    |> with_permission("operable:echo")
    |> with_permission("operable:thorn")

    message = send_message(~s(@#{@bot}: seed '[{"test": "blah"}]' | echo $test))
    assert_response "blah", after: message
  end

  test "running commands in a pipeline without permission", %{user: user} do
    user |> with_permission("operable:st-echo")

    message = send_message(~s(@#{@bot}: operable:st-echo "this is a test" | operable:st-thorn $body))
    assert_response_contains "Sorry, you aren't allowed to execute 'operable:st-thorn $body' :(\n You will need the 'operable:st-thorn' permission to run this command.", after: message
  end

  test "an ambiguous redirect fails" do
    message = send_message(~s(@#{@bot}: operable:echo foo > am_i_user_or_room))

    expected_response = """
    No commands were executed because the following redirects are invalid:

    am_i_user_or_room


    The following redirects are ambiguous; please refer to users and
    rooms according to the conventions of your chat provider
    (e.g. `@user`, `#room`):

    am_i_user_or_room
    """

    assert_response_contains expected_response, after: message
  end
end

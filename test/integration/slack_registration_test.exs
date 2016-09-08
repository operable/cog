defmodule Integration.SlackRegistrationTest do
  use Cog.AdapterCase, adapter: "slack"

  alias Cog.Repository.Users
  alias Cog.Models.User

  @moduletag :slack

  # Name of the Slack user we'll be interacting with the bot as
  @user "botci"

  # Name of the bot we'll be operating as
  @bot "deckard"

  test "executing a command without a registered handle" do
    message = send_message("@#{@bot}: operable:echo If only Cog could automatically register me!")
    assert_response("@#{@user}: I'm terribly sorry, but either I don't have a Cog account for you, or your Slack chat handle has not been registered. Currently, only registered users can interact with me.\n\nYou'll need to ask a Cog administrator to fix this situation and to register your Slack handle.",
                    after: message)
  end

  test "autoregistration" do
    enable_autoregistration
    message = send_message("@#{@bot}: operable:echo Yay, I autoregistered!")

    # We should get a confirmation message, as well as the actual
    # output of the command
    assert_response("@#{@user}: Hello #{@user}! It's great to meet you! You're the proud owner of a shiny new Cog account named '#{@user}'.\nYay, I autoregistered!",
                    after: message,
                    count: 2)
  end

  test "autoregistration after a few tries" do
    enable_autoregistration

    # We'll try to create users up to 20 times. We'll just add a few
    # dummy users to burn up a few of those tries.
    max = 5

    # override the email address, because the one coming in from Slack
    # is actually "#{@user}@operable.io", which would be the default
    # for this test function
    user(@user, email_address: "#{@user}_0@operable.io")
    Enum.each(1..max, &user("#{@user}_#{&1}"))

    expected_username = "#{@user}_#{max+1}"
    assert {:error, :not_found} = Users.by_username(expected_username)

    message = send_message("@#{@bot}: operable:echo I am slow but I get there eventually")

    # We should get a confirmation message, as well as the actual
    # output of the command
    assert_response("@#{@user}: Hello #{@user}! It's great to meet you! You're the proud owner of a shiny new Cog account named '#{expected_username}'.\nI am slow but I get there eventually",
                     after: message,
                     count: 2)

    assert {:ok, %User{username: ^expected_username}} = Users.by_username(expected_username)
  end

  test "autoregistration can eventually fail" do
    enable_autoregistration

    # This is how many times we'll try to create a new Cog user. We'll
    # just create this many users to take up all our slack and trigger
    # the failure
    max = 20

    # override the email address, because the one coming in from Slack
    # is actually "#{@user}@operable.io", which would be the default
    # for this test function
    user(@user, email_address: "#{@user}_0@operable.io")
    Enum.each(1..max, &user("#{@user}_#{&1}"))

    message = send_message("@#{@bot}: operable:echo alas it was not meant to be")
    assert_response("@#{@user}: Unfortunately I was unable to automatically create a Cog account for your Slack chat handle. Only users with Cog accounts can interact with me.\n\nYou'll need to ask a Cog administrator to investigate the situation and set up your account.",
                    after: message)
  end

  ########################################################################

  defp enable_autoregistration do
    old_value = Application.get_env(:cog, :self_registration)
    on_exit(fn() ->
      Application.put_env(:cog, :self_registration, old_value)
    end)
    Application.put_env(:cog, :self_registration, true)
  end
end

defmodule Cog.Chat.Slack.Helpers do
  @doc ~S"""
  Turns a Slack user ID (`"U…"`), direct message ID (`"D…"`), or bot ID (`"B…"`)
  into a string in the format "@USER_NAME".
  """
  def lookup_user_name(direct_message_id = "D" <> _id, slack) do
    lookup_user_name(slack.ims[direct_message_id].user, slack)
  end
  def lookup_user_name(user_id = "U" <> _id, slack) do
    "@" <> slack.users[user_id].profile.display_name
  end
  def lookup_user_name(bot_id = "B" <> _id, slack) do
    "@" <> slack.bots[bot_id].profile.display_name
  end

  def get_username(user) do
    if user.is_bot or user.name == "slackbot" do
      user.name
    else
      user.profile.display_name
    end
  end
end

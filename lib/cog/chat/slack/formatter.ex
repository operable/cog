defmodule Cog.Chat.Slack.Formatter do
  @channel ~r/<\#([CG].*)(\|(.*))?>/U
  @user    ~r/<\@(U.*)(\|(.*))?>/U
  @command ~r/<\!(.*)(\|(.*))?>/U
  @link    ~r/<(.*)(\|(.*))?>/U

  def unescape(message, slack) do
    message
    |> unescape_channels(slack)
    |> unescape_users(slack)
    |> unescape_commands
    |> unescape_links
  end

  defp unescape_channels(message, slack) do
    Regex.replace(@channel, message, fn
      _match, channel_id, "", "" ->
        Slack.Lookups.lookup_channel_name(channel_id, slack)
      _match, _channel_id, _right, channel_name ->
        "#" <> channel_name
    end)
  end

  defp unescape_users(message, slack) do
    Regex.replace(@user, message, fn
      _match, user_id, "", "" ->
        Slack.Lookups.lookup_user_name(user_id, slack)
      _match, _user_id, _right, user_name ->
        "@" <> user_name
    end)
  end

  defp unescape_commands(message) do
    Regex.replace(@command, message, fn
      _match, command_name, "", "" ->
        "@" <> command_name
      _match, _command_name, _right, label ->
        "@" <> label
    end)
  end

  defp unescape_links(message) do
    Regex.replace(@link, message, fn
      _match, full_link, "", "" ->
        full_link
      _match, _full_link, _right, short_link ->
        short_link
    end)
  end
end

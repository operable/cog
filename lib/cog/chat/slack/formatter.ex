defmodule Cog.Chat.Slack.Formatter do

  @redirect_symbol "&gt;"

  @channel ~r/<\#(C.*)(\|(.*))?>/U
  @user    ~r/<\@(U.*)(\|(.*))?>/U
  @command ~r/<\!(.*)(\|(.*))?>/U
  @link    ~r/<(.*)(\|(.*))?>/U

  def unescape(original_message, slack) do
    {message, redirects} = split_redirects(original_message)

    message
    |> unescape_channels(slack)
    |> unescape_users(slack)
    |> unescape_commands
    |> unescape_links
    |> append_redirects(redirects)
  end

  defp unescape_channels(message, slack) do
    replace(message, @channel, fn original ->
      case Regex.run(@channel, original) do
        [^original, channel_id] ->
          Slack.Lookups.lookup_channel_name(channel_id, slack)
        [^original, _channel_id, _right, channel_name] ->
          "#" <> channel_name
      end
    end)
  end

  defp unescape_users(message, slack) do
    replace(message, @user, fn original ->
      case Regex.run(@user, original) do
        [^original, user_id] ->
          Slack.Lookups.lookup_user_name(user_id, slack)
        [^original, _user_id, _right, user_name] ->
          "@" <> user_name
      end
    end)
  end

  defp unescape_commands(message) do
    replace(message, @command, fn original ->
      case Regex.run(@command, original) do
        [^original, command_name] ->
          "@" <> command_name
        [^original, _command_name, _right, label] ->
          "@" <> label
      end
    end)
  end

  defp unescape_links(message) do
    replace(message, @link, fn original ->
      case Regex.run(@link, original) do
        [^original, full_link] ->
          full_link
        [^original, _full_link, _right, short_link] ->
          short_link
      end
    end)
  end

  defp replace(message, regex, replace_fun) do
    case Regex.run(regex, message, return: :index) do
      nil ->
        message
      [{start, length}|_] ->
        original = String.slice(message, start, length)
        replacement = replace_fun.(original)

        {left, right} = String.split_at(message, start)
        right = String.slice(right, length, String.length(right))
        replace(left <> replacement <> right, regex, replace_fun)
    end
  end

  defp split_redirects(message) do
    case String.split(message, @redirect_symbol, parts: 2) do
      [pipeline, redirects] ->
        {pipeline, redirects}
      [pipeline] ->
        {pipeline, nil}
    end
  end

  defp append_redirects(message, nil),
    do: message
  defp append_redirects(message, redirects),
    do: Enum.join([message, redirects], @redirect_symbol)

end

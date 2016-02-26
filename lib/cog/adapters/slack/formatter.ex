defmodule Cog.Adapters.Slack.Formatter do
  alias Cog.Adapters.Slack

  @channel ~r/<\#(C.*)(\|(.*))?>/U
  @user    ~r/<\@(U.*)(\|(.*))?>/U
  @command ~r/<\!(.*)(\|(.*))?>/U
  @link    ~r/<(.*)(\|(.*))?>/U

  def unescape(message) do
    message
    |> unescape_channels
    |> unescape_users
    |> unescape_commands
    |> unescape_links
  end

  defp unescape_channels(message) do
    replace(message, @channel, fn original ->
      case Regex.run(@channel, original) do
        [^original, channel_id] ->
          {:ok, channel} = Slack.lookup_room(id: channel_id)
          "#" <> Map.get(channel, :name)
        [^original, _channel_id, _right, channel_name] ->
          "#" <> channel_name
      end
    end)
  end

  defp unescape_users(message) do
    replace(message, @user, fn original ->
      case Regex.run(@user, original) do
        [^original, user_id] ->
          {:ok, user} = Slack.API.lookup_user(id: user_id)
          "@" <> Map.get(user, :handle)
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
end

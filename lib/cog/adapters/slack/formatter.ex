defmodule Cog.Adapters.Slack.Formatter do
  # "Hello <@U024BE7LH|bob>" => "Hello @bob"
  def unescape(message) do
    message
    |> unescape_channels
    |> unescape_users
    |> unescape_commands
    |> unescape_links
  end

  defp unescape_channels(message) do
    message
    |> String.replace(~r/<\#C.*\|(.*)>/U, "#\\1")
  end

  defp unescape_users(message) do
    message
    |> String.replace(~r/<\@U.*\|(.*)>/U, "@\\1")
  end

  defp unescape_commands(message) do
    message
    |> String.replace(~r/<\!.*\|(.*)>/U, "@\\1")
    |> String.replace(~r/<\!(.*)>/U, "@\\1")
  end

  defp unescape_links(message) do
    message
    |> String.replace(~r/<.*\|(.*)>/U, "\\1")
    |> String.replace(~r/<(.*)>/U, "\\1")
  end
end

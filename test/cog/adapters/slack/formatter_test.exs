defmodule Cog.Adapters.Slack.FormatterTest do
  use ExUnit.Case, async: true
  alias Cog.Adapters.Slack.Formatter

  test "unescaping channels" do
    unescaped = Formatter.unescape("Should I join <#C014BE7LR|alpha> or <#C036HA90R|beta>?")
    assert unescaped == "Should I join #alpha or #beta?"
  end

  test "unescaping users" do
    unescaped = Formatter.unescape("Hello <@U9AF923J|imbriaco>!")
    assert unescaped == "Hello @imbriaco!"
  end

  test "unescaping commands" do
    unescaped = Formatter.unescape("I love to wake up early and tell <!everyone> I'm <!here>.")
    assert unescaped == "I love to wake up early and tell @everyone I'm @here."
  end

  test "unescaping links" do
    unescaped = Formatter.unescape("Hey check this out: <https://www.youtube.com/watch?v=dQw4w9WgXcQ>")
    assert unescaped == "Hey check this out: https://www.youtube.com/watch?v=dQw4w9WgXcQ"
  end

  test "unescapeing everything all-in-one" do
    unescaped = Formatter.unescape("Hey <!everyone>, here's that link <@U9AF923J|imbriaco> posted in <#C014BE7LR|alpha>: <https://www.youtube.com/watch?v=dQw4w9WgXcQ>")
    assert unescaped == "Hey @everyone, here's that link @imbriaco posted in #alpha: https://www.youtube.com/watch?v=dQw4w9WgXcQ"
  end
end

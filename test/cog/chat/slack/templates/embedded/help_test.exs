defmodule Cog.Chat.Slack.Templates.Embedded.HelpTest do
  use Cog.TemplateCase

  test "help template" do
    data = %{"results" => [%{"bundle" => %{"name" => "test"}, "name" => "one"},
                           %{"bundle" => %{"name" => "test"}, "name" => "two"},
                           %{"bundle" => %{"name" => "test"}, "name" => "three"}]}
    expected = """
    Here are the commands I know about:

    1. test:one
    2. test:two
    3. test:three

    Have a nice day!
    """ |> String.strip
    assert_rendered_template(:slack, :embedded, "help", data, expected)
  end
end

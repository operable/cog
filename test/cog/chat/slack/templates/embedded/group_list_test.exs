defmodule Cog.Chat.Slack.Templates.Embedded.GroupListTest do
  use Cog.TemplateCase

  test "group-list template" do
    data = %{"results" => [%{"name" => "testgroup1"},
                           %{"name" => "testgroup2"},
                           %{"name" => "testgroup3"}]}
    expected = """
    testgroup1
    testgroup2
    testgroup3
    """ |> String.strip()

    assert_rendered_template(:slack, :embedded, "group-list", data, expected)
  end
end

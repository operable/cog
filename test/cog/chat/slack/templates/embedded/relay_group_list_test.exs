defmodule Cog.Chat.Slack.Templates.Embedded.RelayGroupListTest do
  use Cog.TemplateCase

  test "relay-group-list template" do
    data = %{"results" => [%{"name" => "foo"},
                           %{"name" => "bar"},
                           %{"name" => "baz"}]}

    expected = """
    foo
    bar
    baz
    """ |> String.strip

    assert_rendered_template(:slack, :embedded, "relay-group-list", data, expected)
  end

end

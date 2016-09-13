defmodule Cog.Chat.Slack.Templates.Embedded.RelayGroupDeleteTest do
  use Cog.TemplateCase

  test "relay-group-delete template" do
    data = %{"results" => [%{"name" => "foo"}]}
    expected = "Deleted relay-group 'foo'"
    assert_rendered_template(:slack, :embedded, "relay-group-delete", data, expected)
  end

  test "relay-group-delete template with multiple inputs" do
    data = %{"results" => [%{"name" => "foo"},
                           %{"name" => "bar"},
                           %{"name" => "baz"}]}
    expected = """
    Deleted relay-group 'foo'
    Deleted relay-group 'bar'
    Deleted relay-group 'baz'
    """ |> String.strip

    assert_rendered_template(:slack, :embedded, "relay-group-delete", data, expected)
  end

end

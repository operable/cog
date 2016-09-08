defmodule Cog.Chat.Slack.Templates.Embedded.RelayGroupCreateTest do
  use Cog.TemplateCase

  test "relay-group-create template" do
    data = %{"results" => [%{"name" => "foo"}]}
    expected = "Created relay-group 'foo'"
    assert_rendered_template(:embedded, "relay-group-create", data, expected)
  end

  test "relay-group-create template with multiple inputs" do
    data = %{"results" => [%{"name" => "foo"},
                           %{"name" => "bar"},
                           %{"name" => "baz"}]}
    expected = """
    Created relay-group 'foo'
    Created relay-group 'bar'
    Created relay-group 'baz'
    """ |> String.strip

    assert_rendered_template(:embedded, "relay-group-create", data, expected)
  end

end

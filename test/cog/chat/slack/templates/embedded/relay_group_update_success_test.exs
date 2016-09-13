defmodule Cog.Chat.Slack.Templates.Embedded.RelayGroupUpdateSuccessTest do
  use Cog.TemplateCase

  test "relay-group-update-success template with one input" do
    data = %{"results" => [%{"name" => "foo"}]}
    expected = "Relay group 'foo' was successfully updated"
    assert_rendered_template(:slack, :embedded, "relay-group-update-success", data, expected)
  end

  test "relay-group-update-success template with multiple inputs" do
    data = %{"results" => [%{"name" => "foo"},
                           %{"name" => "bar"},
                           %{"name" => "baz"}]}
    expected = """
    Relay group 'foo' was successfully updated
    Relay group 'bar' was successfully updated
    Relay group 'baz' was successfully updated
    """ |> String.strip

    assert_rendered_template(:slack, :embedded, "relay-group-update-success", data, expected)
  end

end

defmodule Cog.Chat.Slack.Templates.Embedded.TriggerDisableTest do
  use Cog.TemplateCase

  test "trigger-disable template" do
    data = %{"results" => [%{"name" => "foo"}]}
    expected = "Disabled trigger 'foo'"
    assert_rendered_template(:slack, :embedded, "trigger-disable", data, expected)
  end

  test "trigger-disable template with multiple inputs" do
    data = %{"results" => [%{"name" => "foo"},
                           %{"name" => "bar"},
                           %{"name" => "baz"}]}
    expected = """
    Disabled trigger 'foo'
    Disabled trigger 'bar'
    Disabled trigger 'baz'
    """ |> String.strip

    assert_rendered_template(:slack, :embedded, "trigger-disable", data, expected)
  end

end

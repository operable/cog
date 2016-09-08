defmodule Cog.Chat.Slack.Templates.Embedded.TriggerEnableTest do
  use Cog.TemplateCase

  test "trigger-enable template" do
    data = %{"results" => [%{"name" => "foo"}]}
    expected = "Enabled trigger 'foo'"
    assert_rendered_template(:embedded, "trigger-enable", data, expected)
  end

  test "trigger-enable template with multiple inputs" do
    data = %{"results" => [%{"name" => "foo"},
                           %{"name" => "bar"},
                           %{"name" => "baz"}]}
    expected = """
    Enabled trigger 'foo'
    Enabled trigger 'bar'
    Enabled trigger 'baz'
    """ |> String.strip

    assert_rendered_template(:embedded, "trigger-enable", data, expected)
  end

end

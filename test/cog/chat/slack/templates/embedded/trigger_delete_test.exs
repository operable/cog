defmodule Cog.Chat.Slack.Templates.Embedded.TriggerDeleteTest do
  use Cog.TemplateCase

  test "trigger-delete template" do
    data = %{"results" => [%{"name" => "foo"}]}
    expected = "Deleted trigger 'foo'"
    assert_rendered_template(:embedded, "trigger-delete", data, expected)
  end

  test "trigger-delete template with multiple inputs" do
    data = %{"results" => [%{"name" => "foo"},
                           %{"name" => "bar"},
                           %{"name" => "baz"}]}
    expected = """
    Deleted trigger 'foo'
    Deleted trigger 'bar'
    Deleted trigger 'baz'
    """ |> String.strip

    assert_rendered_template(:embedded, "trigger-delete", data, expected)
  end

end

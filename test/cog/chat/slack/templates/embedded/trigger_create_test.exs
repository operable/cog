defmodule Cog.Chat.Slack.Templates.Embedded.TriggerCreateTest do
  use Cog.TemplateCase

  test "trigger-create template" do
    data = %{"results" => [%{"id" => "12345"}]}
    expected = "Created trigger '12345'"
    assert_rendered_template(:slack, :embedded, "trigger-create", data, expected)
  end

  test "trigger-create template with multiple inputs" do
    data = %{"results" => [%{"id" => "12345"},
                           %{"id" => "67890"},
                           %{"id" => "11111"}]}
    expected = """
    Created trigger '12345'
    Created trigger '67890'
    Created trigger '11111'
    """ |> String.strip

    assert_rendered_template(:slack, :embedded, "trigger-create", data, expected)
  end

end

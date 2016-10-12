defmodule Cog.Chat.Slack.Templates.Embedded.RuleCreateTest do
  use Cog.TemplateCase

  test "rule-create template" do
    data = %{"results" => [%{"id" => "12345"}]}
    expected = "Created rule '12345'"
    assert_rendered_template(:slack, :embedded, "rule-create", data, expected)
  end

  test "rule-create template with multiple inputs" do
    data = %{"results" => [%{"id" => "12345"},
                           %{"id" => "67890"},
                           %{"id" => "11111"}]}
    expected = """
    Created rule '12345'
    Created rule '67890'
    Created rule '11111'
    """ |> String.strip

    assert_rendered_template(:slack, :embedded, "rule-create", data, expected)
  end

end

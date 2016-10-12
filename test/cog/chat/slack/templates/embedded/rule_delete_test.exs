defmodule Cog.Chat.Slack.Templates.Embedded.RuleDeleteTest do
  use Cog.TemplateCase

  test "rule-delete template" do
    data = %{"results" => [%{"id" => "12345"}]}
    expected = "Deleted rule '12345'"
    assert_rendered_template(:slack, :embedded, "rule-delete", data, expected)
  end

  test "rule-delete template with multiple inputs" do
    data = %{"results" => [%{"id" => "12345"},
                           %{"id" => "67890"},
                           %{"id" => "11111"}]}
    expected = """
    Deleted rule '12345'
    Deleted rule '67890'
    Deleted rule '11111'
    """ |> String.strip

    assert_rendered_template(:slack, :embedded, "rule-delete", data, expected)
  end

end

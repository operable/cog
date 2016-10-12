defmodule Cog.Chat.HipChat.Templates.Embedded.RuleDeleteTest do
  use Cog.TemplateCase

  test "rule-delete template" do
    data = %{"results" => [%{"id" => "12345"}]}
    expected = "Deleted rule '12345'"
    assert_rendered_template(:hipchat, :embedded, "rule-delete", data, expected)
  end

  test "rule-delete template with multiple inputs" do
    data = %{"results" => [%{"id" => "12345"},
                           %{"id" => "67890"},
                           %{"id" => "11111"}]}
    expected = "Deleted rule '12345'<br/>" <>
      "Deleted rule '67890'<br/>" <>
      "Deleted rule '11111'"

    assert_rendered_template(:hipchat, :embedded, "rule-delete", data, expected)
  end

end

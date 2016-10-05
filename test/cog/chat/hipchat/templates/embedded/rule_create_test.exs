defmodule Cog.Chat.HipChat.Templates.Embedded.RuleCreateTest do
  use Cog.TemplateCase

  test "rule-create template" do
    data = %{"results" => [%{"id" => "12345"}]}
    expected = "Created rule '12345'"
    assert_rendered_template(:hipchat, :embedded, "rule-create", data, expected)
  end

  test "rule-create template with multiple inputs" do
    data = %{"results" => [%{"id" => "12345"},
                           %{"id" => "67890"},
                           %{"id" => "11111"}]}
    expected = "Created rule '12345'<br/>" <>
      "Created rule '67890'<br/>" <>
      "Created rule '11111'"

    assert_rendered_template(:hipchat, :embedded, "rule-create", data, expected)
  end

end

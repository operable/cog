defmodule Cog.Chat.HipChat.Templates.Embedded.TriggerCreateTest do
  use Cog.TemplateCase

  test "trigger-create template" do
    data = %{"results" => [%{"id" => "12345"}]}
    expected = "Created trigger '12345'"
    assert_rendered_template(:hipchat, :embedded, "trigger-create", data, expected)
  end

  test "trigger-create template with multiple inputs" do
    data = %{"results" => [%{"id" => "12345"},
                           %{"id" => "67890"},
                           %{"id" => "11111"}]}
    expected = "Created trigger '12345'<br/>" <>
      "Created trigger '67890'<br/>" <>
      "Created trigger '11111'"

    assert_rendered_template(:hipchat, :embedded, "trigger-create", data, expected)
  end

end

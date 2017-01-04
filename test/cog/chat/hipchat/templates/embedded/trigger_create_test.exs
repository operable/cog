defmodule Cog.Chat.HipChat.Templates.Embedded.TriggerCreateTest do
  use Cog.TemplateCase

  test "trigger-create template" do
    data = %{"results" => [%{"name" => "echo-test"}]}
    expected = "Created trigger 'echo-test'"
    assert_rendered_template(:hipchat, :embedded, "trigger-create", data, expected)
  end

  test "trigger-create template with multiple inputs" do
    data = %{"results" => [%{"name" => "echo-1"},
                           %{"name" => "echo-2"},
                           %{"name" => "echo-3"}]}
    expected = "Created trigger 'echo-1'<br/>" <>
      "Created trigger 'echo-2'<br/>" <>
      "Created trigger 'echo-3'"

    assert_rendered_template(:hipchat, :embedded, "trigger-create", data, expected)
  end

end

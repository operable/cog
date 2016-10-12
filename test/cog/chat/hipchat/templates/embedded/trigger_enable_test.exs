defmodule Cog.Chat.HipChat.Templates.Embedded.TriggerEnableTest do
  use Cog.TemplateCase

  test "trigger-enable template" do
    data = %{"results" => [%{"name" => "foo"}]}
    expected = "Enabled trigger 'foo'"
    assert_rendered_template(:hipchat, :embedded, "trigger-enable", data, expected)
  end

  test "trigger-enable template with multiple inputs" do
    data = %{"results" => [%{"name" => "foo"},
                           %{"name" => "bar"},
                           %{"name" => "baz"}]}
    expected = "Enabled trigger 'foo'<br/>" <>
      "Enabled trigger 'bar'<br/>" <>
      "Enabled trigger 'baz'"

    assert_rendered_template(:hipchat, :embedded, "trigger-enable", data, expected)
  end

end

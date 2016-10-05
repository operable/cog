defmodule Cog.Chat.HipChat.Templates.Embedded.TriggerDisableTest do
  use Cog.TemplateCase

  test "trigger-disable template" do
    data = %{"results" => [%{"name" => "foo"}]}
    expected = "Disabled trigger 'foo'"
    assert_rendered_template(:hipchat, :embedded, "trigger-disable", data, expected)
  end

  test "trigger-disable template with multiple inputs" do
    data = %{"results" => [%{"name" => "foo"},
                           %{"name" => "bar"},
                           %{"name" => "baz"}]}
    expected = "Disabled trigger 'foo'<br/>" <>
      "Disabled trigger 'bar'<br/>" <>
      "Disabled trigger 'baz'"

    assert_rendered_template(:hipchat, :embedded, "trigger-disable", data, expected)
  end

end

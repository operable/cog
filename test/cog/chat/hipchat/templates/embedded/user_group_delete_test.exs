defmodule Cog.Chat.HipChat.Templates.Embedded.UserGroupDeleteTest do
  use Cog.TemplateCase

  test "user-group-delete template" do
    data = %{"results" => [%{"name" => "foo"}]}
    expected = "Deleted user group 'foo'"
    assert_rendered_template(:hipchat, :embedded, "user-group-delete", data, expected)
  end

  test "user-group-delete template with multiple inputs" do
    data = %{"results" => [%{"name" => "foo"},
                           %{"name" => "bar"},
                           %{"name" => "baz"}]}
    expected = "Deleted user group 'foo'<br/>" <>
      "Deleted user group 'bar'<br/>" <>
      "Deleted user group 'baz'"

    assert_rendered_template(:hipchat, :embedded, "user-group-delete", data, expected)
  end

end

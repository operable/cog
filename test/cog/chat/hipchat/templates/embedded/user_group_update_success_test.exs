defmodule Cog.Chat.HipChat.Templates.Embedded.UserGroupUpdateSuccessTest do
  use Cog.TemplateCase

  test "user-group-update-success template" do
    data = %{"results" => [%{"name" => "foo"}]}
    expected = "User group 'foo' was successfully updated"
    assert_rendered_template(:hipchat, :embedded, "user-group-update-success", data, expected)
  end

  test "user-group-update-success template with multiple inputs" do
    data = %{"results" => [%{"name" => "foo"},
                           %{"name" => "bar"},
                           %{"name" => "baz"}]}
    expected = "User group 'foo' was successfully updated<br/>" <>
      "User group 'bar' was successfully updated<br/>" <>
      "User group 'baz' was successfully updated"

    assert_rendered_template(:hipchat, :embedded, "user-group-update-success", data, expected)
  end

end

defmodule Cog.Chat.HipChat.Templates.Embedded.UserGroupCreateTest do
  use Cog.TemplateCase

  test "user-group-create template" do
    data = %{"results" => [%{"name" => "foo"}]}
    expected = "Created user group 'foo'"
    assert_rendered_template(:hipchat, :embedded, "user-group-create", data, expected)
  end

  test "user-group-create template with multiple inputs" do
    data = %{"results" => [%{"name" => "foo"},
                           %{"name" => "bar"},
                           %{"name" => "baz"}]}
    expected = "Created user group 'foo'<br/>" <>
      "Created user group 'bar'<br/>" <>
      "Created user group 'baz'"

    assert_rendered_template(:hipchat, :embedded, "user-group-create", data, expected)
  end

end

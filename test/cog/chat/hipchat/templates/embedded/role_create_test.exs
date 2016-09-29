defmodule Cog.Chat.HipChat.Templates.Embedded.RoleCreateTest do
  use Cog.TemplateCase

  test "role-create template" do
    data = %{"results" => [%{"name" => "foo"}]}
    expected = "Created role 'foo'"
    assert_rendered_template(:hipchat, :embedded, "role-create", data, expected)
  end

  test "role-create template with multiple inputs" do
    data = %{"results" => [%{"name" => "foo"},
                           %{"name" => "bar"},
                           %{"name" => "baz"}]}
    expected = "Created role 'foo'<br/>" <>
      "Created role 'bar'<br/>" <>
      "Created role 'baz'"

    assert_rendered_template(:hipchat, :embedded, "role-create", data, expected)
  end

end

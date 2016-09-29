defmodule Cog.Chat.HipChat.Templates.Embedded.RoleDeleteTest do
  use Cog.TemplateCase

  test "role-delete template" do
    data = %{"results" => [%{"name" => "foo"}]}
    expected = "Deleted role 'foo'"
    assert_rendered_template(:hipchat, :embedded, "role-delete", data, expected)
  end

  test "role-delete template with multiple inputs" do
    data = %{"results" => [%{"name" => "foo"},
                           %{"name" => "bar"},
                           %{"name" => "baz"}]}
    expected = "Deleted role 'foo'<br/>" <>
      "Deleted role 'bar'<br/>" <>
      "Deleted role 'baz'"

    assert_rendered_template(:hipchat, :embedded, "role-delete", data, expected)
  end

end

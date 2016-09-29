defmodule Cog.Chat.HipChat.Templates.Embedded.PermissionDeleteTest do
  use Cog.TemplateCase

  test "permission-delete template" do
    data = %{"results" => [%{"bundle" => "site", "name" => "foo"}]}
    expected = "Deleted permission 'site:foo'"
    assert_rendered_template(:hipchat, :embedded, "permission-delete", data, expected)
  end

  test "permission-delete template with multiple inputs" do
    data = %{"results" => [%{"bundle" => "site", "name" => "foo"},
                           %{"bundle" => "site", "name" => "bar"},
                           %{"bundle" => "site", "name" => "baz"}]}
    expected = "Deleted permission 'site:foo'<br/>" <>
      "Deleted permission 'site:bar'<br/>" <>
      "Deleted permission 'site:baz'"

    assert_rendered_template(:hipchat, :embedded, "permission-delete", data, expected)
  end

end

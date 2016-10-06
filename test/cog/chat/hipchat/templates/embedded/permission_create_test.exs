defmodule Cog.Chat.HipChat.Templates.Embedded.PermissionCreateTest do
  use Cog.TemplateCase

  test "permission-create template" do
    data = %{"results" => [%{"bundle" => "site", "name" => "foo"}]}
    expected = "Created permission 'site:foo'"
    assert_rendered_template(:hipchat, :embedded, "permission-create", data, expected)
  end

  test "permission-create template with multiple inputs" do
    data = %{"results" => [%{"bundle" => "site", "name" => "foo"},
                           %{"bundle" => "site", "name" => "bar"},
                           %{"bundle" => "site", "name" => "baz"}]}
    expected = "Created permission 'site:foo'<br/>" <>
      "Created permission 'site:bar'<br/>" <>
      "Created permission 'site:baz'"

    assert_rendered_template(:hipchat, :embedded, "permission-create", data, expected)
  end

end

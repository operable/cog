defmodule Cog.Chat.HipChat.Templates.Embedded.PermissionRevokeTest do
  use Cog.TemplateCase

  test "permission-revoke template" do
    data = %{"results" => [%{"permission" => %{"bundle" => "site",
                                               "name" => "foo"},
                             "role" => %{"name" => "ops"}}]}

    expected = "Revoked permission 'site:foo' from role 'ops'"
    assert_rendered_template(:hipchat, :embedded, "permission-revoke", data, expected)
  end

  test "permission-revoke template with multiple inputs" do
    data = %{"results" => [%{"permission" => %{"bundle" => "site", "name" => "foo"},
                             "role" => %{"name" => "ops"}},
                           %{"permission" => %{"bundle" => "site", "name" => "bar"},
                             "role" => %{"name" => "dev"}},
                           %{"permission" => %{"bundle" => "site", "name" => "baz"},
                             "role" => %{"name" => "sec"}}]}

    expected = "Revoked permission 'site:foo' from role 'ops'<br/>" <>
      "Revoked permission 'site:bar' from role 'dev'<br/>" <>
      "Revoked permission 'site:baz' from role 'sec'"

    assert_rendered_template(:hipchat, :embedded, "permission-revoke", data, expected)
  end

end

defmodule Cog.Chat.HipChat.Templates.Embedded.RoleRevokeTest do
  use Cog.TemplateCase

  test "role-revoke template" do
    data = %{"results" => [%{"role" => %{"name" => "admin"},
                             "group" => %{"name" => "ops"}}]}

    expected = "Revoked role 'admin' from group 'ops'"
    assert_rendered_template(:hipchat, :embedded, "role-revoke", data, expected)
  end

  test "role-revoke template with multiple inputs" do
    data = %{"results" => [%{"role" => %{"name" => "cog-admin"},
                             "group" => %{"name" => "ops"}},
                           %{"role" => %{"name" => "aws-admin"},
                             "group" => %{"name" => "developers"}},
                           %{"role" => %{"name" => "heroku-admin"},
                             "group" => %{"name" => "developers"}}]}

    expected = "Revoked role 'cog-admin' from group 'ops'<br/>" <>
      "Revoked role 'aws-admin' from group 'developers'<br/>" <>
      "Revoked role 'heroku-admin' from group 'developers'"

    assert_rendered_template(:hipchat, :embedded, "role-revoke", data, expected)
  end



end

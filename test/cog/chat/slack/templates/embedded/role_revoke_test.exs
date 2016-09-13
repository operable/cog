defmodule Cog.Chat.Slack.Templates.Embedded.RoleRevokeTest do
  use Cog.TemplateCase

  test "role-revoke template" do
    data = %{"results" => [%{"role" => %{"name" => "admin"},
                             "group" => %{"name" => "ops"}}]}

    expected = "Revoked role 'admin' from group 'ops'"
    assert_rendered_template(:slack, :embedded, "role-revoke", data, expected)
  end

  test "role-revoke template with multiple inputs" do
    data = %{"results" => [%{"role" => %{"name" => "cog-admin"},
                             "group" => %{"name" => "ops"}},
                           %{"role" => %{"name" => "aws-admin"},
                             "group" => %{"name" => "developers"}},
                           %{"role" => %{"name" => "heroku-admin"},
                             "group" => %{"name" => "developers"}}]}

    expected = """
    Revoked role 'cog-admin' from group 'ops'
    Revoked role 'aws-admin' from group 'developers'
    Revoked role 'heroku-admin' from group 'developers'
    """ |> String.strip

    assert_rendered_template(:slack, :embedded, "role-revoke", data, expected)
  end



end

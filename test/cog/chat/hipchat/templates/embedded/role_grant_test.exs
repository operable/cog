defmodule Cog.Chat.HipChat.Templates.Embedded.RoleGrantTest do
  use Cog.TemplateCase

  test "role-grant template" do
    data = %{"results" => [%{"role" => %{"name" => "admin"},
                             "group" => %{"name" => "ops"}}]}

    expected = "Granted role 'admin' to group 'ops'"
    assert_rendered_template(:hipchat, :embedded, "role-grant", data, expected)
  end

  test "role-grant template with multiple inputs" do
    data = %{"results" => [%{"role" => %{"name" => "cog-admin"},
                             "group" => %{"name" => "ops"}},
                           %{"role" => %{"name" => "aws-admin"},
                             "group" => %{"name" => "developers"}},
                           %{"role" => %{"name" => "heroku-admin"},
                             "group" => %{"name" => "developers"}}]}

    expected = "Granted role 'cog-admin' to group 'ops'<br/>" <>
      "Granted role 'aws-admin' to group 'developers'<br/>" <>
      "Granted role 'heroku-admin' to group 'developers'"

    assert_rendered_template(:hipchat, :embedded, "role-grant", data, expected)
  end



end

defmodule Cog.Chat.Slack.Templates.Embedded.RoleListTest do
  use Cog.TemplateCase

  test "role-list template" do
    data = %{"results" => [%{"name" => "foo"},
                           %{"name" => "bar"},
                           %{"name" => "baz",
                             "permissions" => [%{"name": "manage_users",
                                                 "id": "a598628c-c2d8-4ace-9abc-29467e35f5e0",
                                                 "bundle": "operable"}]}]}

    attachments = [
      "foo (0 permissions)",
      "bar (0 permissions)",
      "baz (1 permissions)"
    ]

    assert_rendered_template(:slack, :embedded, "role-list", data, {"", attachments})
  end

end

defmodule Cog.Chat.Slack.Templates.Embedded.PermissionListTest do
  use Cog.TemplateCase

  test "permission-list template" do
    data = %{"results" => [%{"bundle" => "site", "name" => "foo"},
                           %{"bundle" => "site", "name" => "bar"},
                           %{"bundle" => "site", "name" => "baz"}]}

    attachments = [
      "site:foo",
      "site:bar",
      "site:baz"
    ]

    assert_rendered_template(:slack, :embedded, "permission-list", data, {"", attachments})
  end

end

defmodule Cog.Chat.Slack.Templates.Embedded.PermissionListTest do
  use Cog.TemplateCase

  test "permission-list template" do
    data = %{"results" => [%{"bundle" => "site", "name" => "foo"},
                           %{"bundle" => "site", "name" => "bar"},
                           %{"bundle" => "site", "name" => "baz"}]}

    attachments = [
      """
      *Name:* foo
      *Bundle:* site
      """,
      """
      *Name:* bar
      *Bundle:* site
      """,
      """
      *Name:* baz
      *Bundle:* site
      """
    ] |> Enum.map(&String.strip/1)

    assert_rendered_template(:slack, :embedded, "permission-list", data, {"", attachments})
  end

end

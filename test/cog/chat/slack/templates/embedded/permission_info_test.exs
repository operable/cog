defmodule Cog.Chat.Slack.Templates.Embedded.PermissionInfoTest do
  use Cog.TemplateCase

  test "permission-info template" do
    data = %{"results" => [%{"id" => "123", "bundle" => "site", "name" => "foo"}]}

    expected = """
    *Name:* site:foo
    *ID:* 123
    """ |> String.strip

    assert_rendered_template(:slack, :embedded, "permission-info", data, expected)
  end
end

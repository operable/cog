defmodule Cog.Chat.HipChat.Templates.Embedded.PermissionListTest do
  use Cog.TemplateCase

  test "permission-list template" do
    data = %{"results" => [%{"bundle" => "site", "name" => "foo"},
                           %{"bundle" => "site", "name" => "bar"},
                           %{"bundle" => "site", "name" => "baz"}]}

    expected = """
    <table>
    <th><td>Bundle</td><td>Name</td></th>
    <tr><td>site</td><td>foo</td></tr>
    <tr><td>site</td><td>bar</td></tr>
    <tr><td>site</td><td>baz</td></tr>
    </table>
    """

    assert_rendered_template(:hipchat, :embedded, "permission-list", data, expected)
  end

end

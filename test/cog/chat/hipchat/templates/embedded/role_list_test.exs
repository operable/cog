defmodule Cog.Chat.HipChat.Templates.Embedded.RoleListTest do
  use Cog.TemplateCase

  test "role-list template" do
    data = %{"results" => [%{"name" => "foo"},
                           %{"name" => "bar"},
                           %{"name" => "baz"}]}

    expected = """
    <table>
    <th><td>Name</td></th>
    <tr><td>foo</td></tr>
    <tr><td>bar</td></tr>
    <tr><td>baz</td></tr>
    </table>
    """

    assert_rendered_template(:hipchat, :embedded, "role-list", data, expected)
  end

end

defmodule Cog.Chat.HipChat.Templates.Embedded.RelayGroupListTest do
  use Cog.TemplateCase

  test "relay-group-list template" do
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

    assert_rendered_template(:hipchat, :embedded, "relay-group-list", data, expected)
  end

end

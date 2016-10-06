defmodule Cog.Chat.HipChat.Templates.Embedded.RuleListTest do
  use Cog.TemplateCase

  test "rule-list template" do
    data = %{"results" => [%{"command" => "foo:foo",
                             "rule" => "when command is foo:foo allow",
                             "id" => "123"},
                           %{"command" => "foo:bar",
                             "rule" => "when command is foo:bar allow",
                             "id" => "456"},
                           %{"command" => "foo:baz",
                             "rule" => "when command is foo:baz allow",
                             "id" => "789"}]}
    expected = """
    <table>
    <th><td>Command</td><td>Rule</td><td>ID</td></th>
    <tr><td>foo:foo</td><td>when command is foo:foo allow</td><td>123</td></tr>
    <tr><td>foo:bar</td><td>when command is foo:bar allow</td><td>456</td></tr>
    <tr><td>foo:baz</td><td>when command is foo:baz allow</td><td>789</td></tr>
    </table>
    """

    assert_rendered_template(:hipchat, :embedded, "rule-list", data, expected)
  end

end

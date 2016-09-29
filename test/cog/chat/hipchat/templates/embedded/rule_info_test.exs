defmodule Cog.Chat.HipChat.Templates.Embedded.RuleInfoTest do
  use Cog.TemplateCase

  test "rule-info template" do
    data = %{"results" => [%{"command_name" => "foo:foo",
                             "rule" => "when command is foo:foo allow",
                             "id" => "123"}]}
    expected = "<strong>ID</strong>: 123<br/>" <>
      "<strong>Command</strong>: foo:foo<br/>" <>
      "<strong>Rule</strong>: when command is foo:foo allow"

    assert_rendered_template(:hipchat, :embedded, "rule-info", data, expected)
  end

  test "rule-info template with multiple rules" do
    data = %{"results" => [%{"command_name" => "foo:foo",
                             "rule" => "when command is foo:foo allow",
                             "id" => "123"},
                           %{"command_name" => "foo:bar",
                             "rule" => "when command is foo:bar allow",
                             "id" => "456"},
                           %{"command_name" => "foo:baz",
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

    assert_rendered_template(:hipchat, :embedded, "rule-info", data, expected)
  end


end

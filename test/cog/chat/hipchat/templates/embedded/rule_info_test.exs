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
    <pre>+---------+-------------------------------+-----+
    | Command | Rule                          | ID  |
    +---------+-------------------------------+-----+
    | foo:foo | when command is foo:foo allow | 123 |
    | foo:bar | when command is foo:bar allow | 456 |
    | foo:baz | when command is foo:baz allow | 789 |
    +---------+-------------------------------+-----+
    </pre>\
    """

    assert_rendered_template(:hipchat, :embedded, "rule-info", data, expected)
  end


end

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
    <pre>+---------+-------------------------------+-----+
    | Command | Rule                          | ID  |
    +---------+-------------------------------+-----+
    | foo:foo | when command is foo:foo allow | 123 |
    | foo:bar | when command is foo:bar allow | 456 |
    | foo:baz | when command is foo:baz allow | 789 |
    +---------+-------------------------------+-----+
    </pre>\
    """

    assert_rendered_template(:hipchat, :embedded, "rule-list", data, expected)
  end

end

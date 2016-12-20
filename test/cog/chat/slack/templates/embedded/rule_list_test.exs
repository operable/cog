defmodule Cog.Chat.Slack.Templates.Embedded.RuleListTest do
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
    attachments = [
      """
      *Command:* foo:foo
      *ID:* 123
      *Rule:*

      ```when command is foo:foo allow```
      """,
      """
      *Command:* foo:bar
      *ID:* 456
      *Rule:*

      ```when command is foo:bar allow```
      """, 
      """
      *Command:* foo:baz
      *ID:* 789
      *Rule:*

      ```when command is foo:baz allow```
      """
    ] |> Enum.map(&String.strip/1)

    assert_rendered_template(:slack, :embedded, "rule-list", data, {"", attachments})
  end

end

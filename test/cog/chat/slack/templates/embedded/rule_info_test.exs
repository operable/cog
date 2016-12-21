defmodule Cog.Chat.Slack.Templates.Embedded.RuleInfoTest do
  use Cog.TemplateCase

  test "rule-info template" do
    data = %{"results" => [%{"command_name" => "foo:foo",
                             "rule" => "when command is foo:foo allow",
                             "id" => "123"}]}
    expected = """
    *ID:* 123
    *Command:* foo:foo
    *Rule:*

    ```when command is foo:foo allow```
    """ |> String.strip

    assert_rendered_template(:slack, :embedded, "rule-info", data, {expected, []})
  end
end

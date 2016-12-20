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
    <strong>Command:</strong> foo:foo<br/>
    <strong>ID:</strong> 123<br/>
    <strong>Rule:</strong><pre>when command is foo:foo allow</pre><br/>
    <br/>
    <strong>Command:</strong> foo:bar<br/>
    <strong>ID:</strong> 456<br/>
    <strong>Rule:</strong><pre>when command is foo:bar allow</pre><br/>
    <br/>
    <strong>Command:</strong> foo:baz<br/>
    <strong>ID:</strong> 789<br/>
    <strong>Rule:</strong><pre>when command is foo:baz allow</pre>
    """ |> String.replace("\n", "")

    assert_rendered_template(:hipchat, :embedded, "rule-list", data, expected)
  end

end

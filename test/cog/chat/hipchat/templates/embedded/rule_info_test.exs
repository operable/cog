defmodule Cog.Chat.HipChat.Templates.Embedded.RuleInfoTest do
  use Cog.TemplateCase

  test "rule-info template" do
    data = %{"results" => [%{"command_name" => "foo:foo",
                             "rule" => "when command is foo:foo allow",
                             "id" => "123"}]}

    expected = """
    <strong>ID:</strong> 123<br/>
    <strong>Rule:</strong><br/>
    <pre>when command is foo:foo allow</pre>
    """ |> String.replace("\n", "")

    assert_rendered_template(:hipchat, :embedded, "rule-info", data, expected)
  end
end

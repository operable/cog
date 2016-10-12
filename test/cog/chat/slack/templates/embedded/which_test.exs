defmodule Cog.Chat.Slack.Templates.Embedded.WhichTest do
  use Cog.TemplateCase

  test "which template - alias result" do
    data = %{"results" => [%{"type" => "alias",
                             "scope" => "site",
                             "name" => "foo",
                             "pipeline" => "echo 'foo'"}]}
    expected = "alias - site:foo -> ```echo 'foo'```"
    assert_rendered_template(:slack, :embedded, "which", data, expected)
  end

  test "which template - command result" do
    data = %{"results" => [%{"type" => "command",
                             "scope" => "operable",
                             "name" => "alias"}]}
    expected = "command - operable:alias"
    assert_rendered_template(:slack, :embedded, "which", data, expected)
  end

  test "which template - multiple inputs" do
    data = %{"results" => [%{"type" => "alias",
                             "scope" => "site",
                             "name" => "foo",
                             "pipeline" => "echo 'foo'"},
                           %{"type" => "command",
                             "scope" => "operable",
                             "name" => "alias"},
                           %{"type" => "alias",
                             "scope" => "user",
                             "name" => "bar",
                             "pipeline" => "echo 'bar'"}]}

    expected = """
    alias - site:foo -> ```echo 'foo'```
    command - operable:alias
    alias - user:bar -> ```echo 'bar'```
    """ |> String.strip
    assert_rendered_template(:slack, :embedded, "which", data, expected)

  end

end

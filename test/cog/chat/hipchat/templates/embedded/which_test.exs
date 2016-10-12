defmodule Cog.Chat.HipChat.Templates.Embedded.WhichTest do
  use Cog.TemplateCase

  test "which template - alias result" do
    data = %{"results" => [%{"type" => "alias",
                             "scope" => "site",
                             "name" => "foo",
                             "pipeline" => "echo 'foo'"}]}
    expected = "alias - site:foo -> <pre>echo 'foo'</pre>"
    assert_rendered_template(:hipchat, :embedded, "which", data, expected)
  end

  test "which template - command result" do
    data = %{"results" => [%{"type" => "command",
                             "scope" => "operable",
                             "name" => "alias"}]}
    expected = "command - operable:alias"
    assert_rendered_template(:hipchat, :embedded, "which", data, expected)
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

    expected = "alias - site:foo -> <pre>echo 'foo'</pre><br/>" <>
      "command - operable:alias<br/>" <>
      "alias - user:bar -> <pre>echo 'bar'</pre>"

    assert_rendered_template(:hipchat, :embedded, "which", data, expected)
  end

end

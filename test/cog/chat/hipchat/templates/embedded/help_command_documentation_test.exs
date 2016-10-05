defmodule Cog.Chat.HipChat.Templates.Embedded.HelpCommandDocumentationTest do
  use Cog.TemplateCase

  test "help-command-documentation template" do
    data = %{"results" => [%{"documentation" => "big ol' doc string"}]}
    expected = "<pre>big ol' doc string\n</pre>"
    assert_rendered_template(:hipchat, :embedded, "help-command-documentation", data, expected)
  end
end

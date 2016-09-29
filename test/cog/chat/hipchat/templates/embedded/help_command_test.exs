defmodule Cog.Chat.HipChat.Templates.Embedded.HelpCommandTest do
  use Cog.TemplateCase

  test "help-command template" do
    data = %{"results" => [%{"documentation" => "big ol' doc string"}]}
    expected = "<pre>big ol' doc string\n</pre>"

    assert_rendered_template(:hipchat, :embedded, "help-command", data, expected)
  end

  # TODO: Can a command ever not have documentation? If so, the
  # template should handle that.

end

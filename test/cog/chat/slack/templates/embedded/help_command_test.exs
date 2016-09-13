defmodule Cog.Chat.Slack.Templates.Embedded.HelpCommandTest do
  use Cog.TemplateCase

  test "help-command template" do
    data = %{"results" => [%{"documentation" => "big ol' doc string"}]}
    expected = """
    ```big ol' doc string
    ```
    """ |> String.strip
    assert_rendered_template(:slack, :embedded, "help-command", data, expected)
  end

  # TODO: Can a command ever not have documentation? If so, the
  # template should handle that.

end

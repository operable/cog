defmodule Cog.Chat.Slack.Templates.Embedded.HelpCommandTest do
  use Cog.TemplateCase

  test "help-command template" do
    data = %{"results" => [%{"name" => "test",
                             "description" => "Do a test thing",
                             "synopsis" => "test --do-a-thing",
                             "bundle" => %{"author" => "vanstee"}}]}
    expected = """
    *Name*

    test - Do a test thing

    *Synopsis*

    ```test --do-a-thing```
    *Author*

    vanstee
    """ |> String.rstrip

    assert_rendered_template(:slack, :embedded, "help-command", data, expected)
  end
end

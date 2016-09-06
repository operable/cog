defmodule Cog.Chat.Slack.Templates.Embedded.HelpTest do
  use Cog.TemplateCase

  test "help template" do
    data = %{"results" => [%{"bundle" => %{"name" => "test"}, "name" => "one"},
                           %{"bundle" => %{"name" => "test"}, "name" => "two"},
                           %{"bundle" => %{"name" => "test"}, "name" => "three"}]}
    expected = """
    Here are the commands I know about:

    test:one
    test:two
    test:three

    Have a nice day!
    """ |> String.strip
    assert_rendered_template(:embedded, "help", data, expected)
  end

  test "help-command template" do
    data = %{"results" => [%{"documentation" => "big ol' doc string"}]}
    expected = """
    ```
    big ol' doc string
    ```
    """ |> String.strip
    assert_rendered_template(:embedded, "help-command", data, expected)
  end

  # TODO: Can a command ever not have documentation? If so, the
  # template should handle that.

end

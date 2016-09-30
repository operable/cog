defmodule Cog.Chat.Slack.Templates.Embedded.HelpBundlesTest do
  use Cog.TemplateCase

  test "help-bundles template" do
    data = %{"results" => [%{"enabled" => [%{"name" => "operable"}],
                             "disabled" => [%{"name" => "test-bundle"}]}]}

    expected = """
    *Enabled Bundles*

    • operable

    *Disabled Bundles*

    • test-bundle

    To learn more about a specific bundle and the commands available within it, you can use \"operable:help <bundle>\".
    """ |> String.rstrip

    assert_rendered_template(:slack, :embedded, "help-bundles", data, expected)
  end
end

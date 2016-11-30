defmodule Cog.Chat.HipChat.Templates.Embedded.HelpBundlesTest do
  use Cog.TemplateCase

  test "help-bundles template" do
    data = %{"results" => [%{"enabled" => [%{"name" => "operable"}],
                             "disabled" => [%{"name" => "test-bundle"}]}]}

    expected = "<strong>Enabled Bundles</strong><br/><br/>" <>
      "<ul><li>operable</li></ul><br/><br/>" <>
      "<strong>Disabled Bundles</strong><br/><br/>" <>
      "<ul><li>test-bundle</li></ul><br/><br/>" <>
      "To learn more about a specific bundle and the commands available within it, you can use \"operable:help <bundle>\"."

    assert_rendered_template(:hipchat, :embedded, "help-bundles", data, expected)
  end
end

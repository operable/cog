defmodule Cog.Chat.HipChat.Templates.Embedded.HelpBundleTest do
  use Cog.TemplateCase

  test "help-bundles template" do
    data = %{"results" => [%{"name" => "test-bundle",
                             "description" => "Does a thing",
                             "long_description" => "No really, it does a thing",
                             "commands" => [%{"name" => "test-command",
                                              "description" => "does just one thing"}],
                             "author" => "vanstee",
                             "homepage" => "test-bundle.com"}]}


    expected = "<strong>Name</strong><br/><br/>" <>
      "test-bundle - Does a thing<br/><br/>" <>
      "<strong>Description</strong><br/><br/>" <>
      "No really, it does a thing<br/><br/>" <>
      "<strong>Commands</strong><br/><br/>" <>
      "<ul><li>test-command - does just one thing</li></ul><br/>" <>
      "<strong>Author</strong><br/><br/>" <>
      "vanstee<br/><br/>" <>
      "<strong>Homepage</strong><br/><br/>" <>
      "test-bundle.com"

    assert_rendered_template(:hipchat, :embedded, "help-bundle", data, expected)
  end
end

defmodule Cog.Chat.HipChat.Templates.Embedded.HelpBundleTest do
  use Cog.TemplateCase

  test "help-bundles template" do
    data = %{"results" => [%{"name" => "test-bundle",
                             "description" => "Does a thing",
                             "long_description" => "No really, it does a thing",
                             "commands" => [%{"name" => "test-command",
                                              "description" => "does just one thing"}],
                             "config" => %{
                               "notes" => "Some notes about config",
                               "env" => [%{"var" => "VAR1", "description" => "description1"},
                                         %{"var" => "VAR2"}]
                             },
                             "author" => "vanstee",
                             "homepage" => "test-bundle.com"}]}


    expected = "<strong>Name</strong><br/><br/>" <>
      "test-bundle - Does a thing<br/><br/><br/>" <>
      "<strong>Description</strong><br/>" <>
      "No really, it does a thing<br/><br/><br/>" <>
      "<strong>Commands</strong><br/>" <>
      "<ul><li><code>test-command</code> - does just one thing</li></ul><br/><br/>" <>
      "<strong>Configuration</strong><br/><br/>" <>
      "Some notes about config<br/>" <>
      "<ul><li><code>VAR1</code> - description1</li><li><code>VAR2</code></li></ul><br/><br/>" <>
      "<strong>Author</strong><br/><br/>" <>
      "vanstee<br/><br/><br/>" <>
      "<strong>Homepage</strong><br/><br/>" <>
      "test-bundle.com"

    assert_rendered_template(:hipchat, :embedded, "help-bundle", data, expected)
  end

  test "help-bundles template without config" do
    data = %{"results" => [%{"name" => "test-bundle",
                             "description" => "Does a thing",
                             "long_description" => "No really, it does a thing",
                             "commands" => [%{"name" => "test-command",
                                              "description" => "does just one thing"}],
                             "author" => "vanstee",
                             "homepage" => "test-bundle.com"}]}


    expected = "<strong>Name</strong><br/><br/>" <>
      "test-bundle - Does a thing<br/><br/><br/>" <>
      "<strong>Description</strong><br/>" <>
      "No really, it does a thing<br/><br/><br/>" <>
      "<strong>Commands</strong><br/>" <>
      "<ul><li><code>test-command</code> - does just one thing</li></ul><br/><br/>" <>
      "<strong>Author</strong><br/><br/>" <>
      "vanstee<br/><br/><br/>" <>
      "<strong>Homepage</strong><br/><br/>" <>
      "test-bundle.com"

    assert_rendered_template(:hipchat, :embedded, "help-bundle", data, expected)
  end
end

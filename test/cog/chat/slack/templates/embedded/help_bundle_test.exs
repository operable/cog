defmodule Cog.Chat.Slack.Templates.Embedded.HelpBundleTest do
  use Cog.TemplateCase

  test "help-bundles template" do
    data = %{"results" => [%{"name" => "test-bundle",
                             "description" => "Does a thing",
                             "long_description" => "No really, it does a thing",
                             "commands" => [%{"name" => "test-command",
                                              "description" => "does just one thing"}],
                             "author" => "vanstee",
                             "config" => %{
                               "notes" => "Some notes about config",
                               "env" => [%{"var" => "VAR1", "description" => "description1"},
                                         %{"var" => "VAR2"}]
                             },
                             "homepage" => "test-bundle.com"}]}


    expected = """
    *Name*

    test-bundle - Does a thing

    *Description*

    No really, it does a thing

    *Configuration*

    Some notes about config

    • VAR1 - description1
    • VAR2

    *Commands*

    • test-command - does just one thing

    *Author*

    vanstee

    *Homepage*

    test-bundle.com
    """ |> String.rstrip

    assert_rendered_template(:slack, :embedded, "help-bundle", data, expected)
  end

  test "help-bundles template without config" do
    data = %{"results" => [%{"name" => "test-bundle",
                             "description" => "Does a thing",
                             "long_description" => "No really, it does a thing",
                             "commands" => [%{"name" => "test-command",
                                              "description" => "does just one thing"}],
                             "author" => "vanstee",
                             "homepage" => "test-bundle.com"}]}


    expected = """
    *Name*

    test-bundle - Does a thing

    *Description*

    No really, it does a thing

    *Commands*

    • test-command - does just one thing

    *Author*

    vanstee

    *Homepage*

    test-bundle.com
    """ |> String.rstrip

    assert_rendered_template(:slack, :embedded, "help-bundle", data, expected)
  end
end

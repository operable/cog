defmodule Cog.Chat.HipChat.Templates.Embedded.HelpTest do
  use Cog.TemplateCase

  test "help template" do
    data = %{"results" => [%{"bundle" => %{"name" => "test"}, "name" => "one"},
                           %{"bundle" => %{"name" => "test"}, "name" => "two"},
                           %{"bundle" => %{"name" => "test"}, "name" => "three"}]}
    expected = "Here are the commands I know about:<br/><br/><br/>" <>
      "<ol><li>test:one</li><li>test:two</li><li>test:three</li></ol><br/>" <>
      "Have a nice day!"

    assert_rendered_template(:hipchat, :embedded, "help", data, expected)
  end
end

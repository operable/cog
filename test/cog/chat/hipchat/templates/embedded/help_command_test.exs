defmodule Cog.Chat.HipChat.Templates.Embedded.HelpCommandTest do
  use Cog.TemplateCase

  test "help-command template" do
    data = %{"results" => [%{"name" => "test",
                             "description" => "Do a test thing",
                             "synopsis" => "test --do-a-thing",
                             "bundle" => %{"author" => "vanstee"}}]}
    expected = "<strong>Name</strong><br/><br/>" <>
      "test - Do a test thing<br/><br/>" <>
      "<strong>Synopsis</strong><br/><br/>" <>
      "<pre>test --do-a-thing</pre><br/>" <>
      "<strong>Author</strong><br/><br/>" <>
      "vanstee<br/>"

    assert_rendered_template(:hipchat, :embedded, "help-command", data, expected)
  end

end

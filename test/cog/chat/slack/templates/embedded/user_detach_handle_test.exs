defmodule Cog.Chat.Slack.Templates.Embedded.UserDetachHandleTest do
  use Cog.TemplateCase

  test "user-detach-handle template" do
    data = %{"results" => [%{"chat_provider" => %{"name" => "Slack"},
                             "username" => "cog"}]}
    expected = "Removed Slack handle from Cog user 'cog'"
    assert_rendered_template(:slack, :embedded, "user-detach-handle", data, expected)
  end

  test "user-detach-handle template with multiple inputs" do
    data = %{"results" => [%{"chat_provider" => %{"name" => "Slack"},
                             "username" => "cog"},
                           %{"chat_provider" => %{"name" => "Slack"},
                             "username" => "sprocket"},
                           %{"chat_provider" => %{"name" => "Slack"},
                             "username" => "herman"}]}
    expected = """
    Removed Slack handle from Cog user 'cog'
    Removed Slack handle from Cog user 'sprocket'
    Removed Slack handle from Cog user 'herman'
    """ |> String.strip

    assert_rendered_template(:slack, :embedded, "user-detach-handle", data, expected)
  end

end

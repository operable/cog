defmodule Cog.Chat.Slack.Templates.Embedded.UserAttachHandleTest do
  use Cog.TemplateCase

  test "user-attach-handle template" do
    data = %{"results" => [%{"chat_provider" => %{"name" => "Slack"},
                             "handle" => "cog",
                             "username" => "cog"}]}
    expected = "Attached Slack handle @cog to Cog user 'cog'"
    assert_rendered_template(:slack, :embedded, "user-attach-handle", data, expected)
  end

  test "user-attach-handle template with multiple inputs" do
    data = %{"results" => [%{"chat_provider" => %{"name" => "Slack"},
                             "handle" => "cog",
                             "username" => "cog"},
                           %{"chat_provider" => %{"name" => "Slack"},
                             "handle" => "sprocket",
                             "username" => "sprocket"},
                           %{"chat_provider" => %{"name" => "Slack"},
                             "handle" => "gear",
                             "username" => "herman"}]}
    expected = """
    Attached Slack handle @cog to Cog user 'cog'
    Attached Slack handle @sprocket to Cog user 'sprocket'
    Attached Slack handle @gear to Cog user 'herman'
    """ |> String.strip

    assert_rendered_template(:slack, :embedded, "user-attach-handle", data, expected)
  end

end

defmodule Cog.Chat.HipChat.Templates.Embedded.UserAttachHandleTest do
  use Cog.TemplateCase

  test "user-attach-handle template" do
    data = %{"results" => [%{"chat_provider" => %{"name" => "HipChat"},
                             "handle" => "cog",
                             "username" => "cog"}]}
    expected = "Attached HipChat handle @cog to Cog user 'cog'"
    assert_rendered_template(:hipchat, :embedded, "user-attach-handle", data, expected)
  end

  test "user-attach-handle template with multiple inputs" do
    data = %{"results" => [%{"chat_provider" => %{"name" => "HipChat"},
                             "handle" => "cog",
                             "username" => "cog"},
                           %{"chat_provider" => %{"name" => "HipChat"},
                             "handle" => "sprocket",
                             "username" => "sprocket"},
                           %{"chat_provider" => %{"name" => "HipChat"},
                             "handle" => "gear",
                             "username" => "herman"}]}
    expected = "Attached HipChat handle @cog to Cog user 'cog'<br/>" <>
      "Attached HipChat handle @sprocket to Cog user 'sprocket'<br/>" <>
      "Attached HipChat handle @gear to Cog user 'herman'"

    assert_rendered_template(:hipchat, :embedded, "user-attach-handle", data, expected)
  end

end

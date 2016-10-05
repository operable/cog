defmodule Cog.Chat.HipChat.Templates.Embedded.UserDetachHandleTest do
  use Cog.TemplateCase

  test "user-detach-handle template" do
    data = %{"results" => [%{"chat_provider" => %{"name" => "HipChat"},
                             "username" => "cog"}]}
    expected = "Removed HipChat handle from Cog user 'cog'"
    assert_rendered_template(:hipchat, :embedded, "user-detach-handle", data, expected)
  end

  test "user-detach-handle template with multiple inputs" do
    data = %{"results" => [%{"chat_provider" => %{"name" => "HipChat"},
                             "username" => "cog"},
                           %{"chat_provider" => %{"name" => "HipChat"},
                             "username" => "sprocket"},
                           %{"chat_provider" => %{"name" => "HipChat"},
                             "username" => "herman"}]}
    expected = "Removed HipChat handle from Cog user 'cog'<br/>" <>
      "Removed HipChat handle from Cog user 'sprocket'<br/>" <>
      "Removed HipChat handle from Cog user 'herman'"

    assert_rendered_template(:hipchat, :embedded, "user-detach-handle", data, expected)
  end

end

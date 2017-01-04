defmodule Cog.Chat.HipChat.Templates.Embedded.UserInfoTest do
  use Cog.TemplateCase

  test "user-info template with one input" do
    data = %{"results" => [%{"username" => "cog",
                             "first_name" => "Cog",
                             "last_name" => "McCog",
                             "email_address" => "cog@example.com",
                             "groups" => [%{"name" => "dev"},
                                          %{"name" => "ops"}],
                             "chat_handles" => [%{"chat_provider" => %{"name" => "HipChat"},
                                                  "handle" => "the_cog"}]}]}

    expected = "<strong>Username</strong>: cog<br/>" <>
      "<strong>First Name</strong>: Cog<br/>" <>
      "<strong>Last Name</strong>: McCog<br/>" <>
      "<strong>Email</strong>: cog@example.com<br/>" <>
      "<strong>Groups</strong>: dev, ops<br/>" <>
      "<strong>Handles</strong>: the_cog (HipChat)"

    assert_rendered_template(:hipchat, :embedded, "user-info", data, expected)
  end
end

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

  @tag :wip
  test "user-info template with multiple inputs" do
    data = %{"results" => [%{"username" => "cog",
                             "first_name" => "Cog",
                             "last_name" => "McCog",
                             "email_address" => "cog@example.com",
                             "groups" => [%{"name" => "dev"},
                                          %{"name" => "ops"}],
                             "chat_handles" => [%{"chat_provider" => %{"name" => "HipChat"},
                                                  "handle" => "the_cog"}]},

                           %{"username" => "sprocket",
                             "first_name" => "Sprocket",
                             "last_name" => "McSprocket",
                             "email_address" => "sprocket@example.com",
                             "groups" => [%{"name" => "sec"},
                                          %{"name" => "test"}],
                             "chat_handles" => [%{"chat_provider" => %{"name" => "HipChat"},
                                                  "handle" => "sprocket"},
                                                %{"chat_provider" => %{"name" => "HipChat"},
                                                  "handle" => "SprocketMcSprocket"}]}
                          ]}
    expected = """
    <pre>+----------+------------+------------+----------------------+-----------+--------------------------------------------------+
    | Username | First Name | Last Name  | Email                | Groups    | Handles                                          |
    +----------+------------+------------+----------------------+-----------+--------------------------------------------------+
    | cog      | Cog        | McCog      | cog@example.com      | dev, ops  | the_cog (HipChat)                                |
    | sprocket | Sprocket   | McSprocket | sprocket@example.com | sec, test | sprocket (HipChat), SprocketMcSprocket (HipChat) |
    +----------+------------+------------+----------------------+-----------+--------------------------------------------------+
    </pre>\
    """

    assert_rendered_template(:hipchat, :embedded, "user-info", data, expected)
  end
end

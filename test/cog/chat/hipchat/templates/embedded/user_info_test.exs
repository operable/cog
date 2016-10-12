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
    <table>
    <th><td>Username</td><td>First Name</td><td>Last Name</td><td>Email</td><td>Groups</td><td>Handles</td></th>
    <tr><td>cog</td><td>Cog</td><td>McCog</td><td>cog@example.com</td><td>dev, ops</td><td>the_cog (HipChat)</td></tr>
    <tr><td>sprocket</td><td>Sprocket</td><td>McSprocket</td><td>sprocket@example.com</td><td>sec, test</td><td>sprocket (HipChat), SprocketMcSprocket (HipChat)</td></tr>
    </table>
    """

    assert_rendered_template(:hipchat, :embedded, "user-info", data, expected)
  end
end

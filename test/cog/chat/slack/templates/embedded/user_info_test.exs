defmodule Cog.Chat.Slack.Templates.Embedded.UserInfoTest do
  use Cog.TemplateCase

  test "user-info template with one input" do
    data = %{"results" => [%{"username" => "cog",
                             "first_name" => "Cog",
                             "last_name" => "McCog",
                             "email_address" => "cog@example.com",
                             "groups" => [%{"name" => "dev"},
                                          %{"name" => "ops"}],
                             "chat_handles" => [%{"chat_provider" => %{"name" => "Slack"},
                                                  "handle" => "the_cog"}]}]}

    expected = """
    *Username*: cog
    *First Name*: Cog
    *Last Name*: McCog
    *Email*: cog@example.com
    *Groups*: dev, ops
    *Handles*: the_cog (Slack)
    """ |> String.strip

    assert_rendered_template(:embedded, "user-info", data, expected)
  end

  test "user-info template with multiple inputs" do
    data = %{"results" => [%{"username" => "cog",
                             "first_name" => "Cog",
                             "last_name" => "McCog",
                             "email_address" => "cog@example.com",
                             "groups" => [%{"name" => "dev"},
                                          %{"name" => "ops"}],
                             "chat_handles" => [%{"chat_provider" => %{"name" => "Slack"},
                                                  "handle" => "the_cog"}]},

                           %{"username" => "sprocket",
                             "first_name" => "Sprocket",
                             "last_name" => "McSprocket",
                             "email_address" => "sprocket@example.com",
                             "groups" => [%{"name" => "sec"},
                                          %{"name" => "test"}],
                             "chat_handles" => [%{"chat_provider" => %{"name" => "Slack"},
                                                  "handle" => "sprocket"},
                                                %{"chat_provider" => %{"name" => "HipChat"},
                                                  "handle" => "SprocketMcSprocket"}]}
                          ]}
    expected = """
    ```+----------+------------+------------+----------------------+-----------+------------------------------------------------+
    | Username | First Name | Last Name  | Email                | Groups    | Handles                                        |
    +----------+------------+------------+----------------------+-----------+------------------------------------------------+
    | cog      | Cog        | McCog      | cog@example.com      | dev, ops  | the_cog (Slack)                                |
    | sprocket | Sprocket   | McSprocket | sprocket@example.com | sec, test | sprocket (Slack), SprocketMcSprocket (HipChat) |
    +----------+------------+------------+----------------------+-----------+------------------------------------------------+
    ```
    """ |> String.strip

    assert_rendered_template(:embedded, "user-info", data, expected)
  end
end

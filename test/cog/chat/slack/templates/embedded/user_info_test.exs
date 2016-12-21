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

    assert_rendered_template(:slack, :embedded, "user-info", data, expected)
  end
end

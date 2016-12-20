defmodule Cog.Chat.Slack.Templates.Embedded.UserListTest do
  use Cog.TemplateCase

  test "user-list template" do
    data = %{"results" => [%{"username" => "cog",
                             "first_name" => "Cog",
                             "last_name" => "McCog",
                             "email_address" => "cog@example.com"},
                           %{"username" => "sprocket",
                             "first_name" => "Sprocket",
                             "last_name" => "McCog",
                             "email_address" => "sprocket@example.com"},
                           %{"username" => "chetops",
                             "first_name" => "Chet",
                             "last_name" => "Ops",
                             "email_address" => "chetops@example.com"}]}

    attachments = [
      """
      *Username:* cog
      *First Name:* Cog
      *Last Name:* McCog
      *Email:* cog@example.com
      """,
      """
      *Username:* sprocket
      *First Name:* Sprocket
      *Last Name:* McCog
      *Email:* sprocket@example.com
      """,
      """
      *Username:* chetops
      *First Name:* Chet
      *Last Name:* Ops
      *Email:* chetops@example.com
      """
    ] |> Enum.map(&String.strip/1)

    assert_rendered_template(:slack, :embedded, "user-list", data, {"", attachments})
  end

  test "handle when names aren't specified" do
    data = %{"results" => [%{"username" => "cog",
                             "first_name" => "Cog",
                             "email_address" => "cog@example.com"},
                           %{"username" => "sprocket",
                             "last_name" => "McCog",
                             "email_address" => "sprocket@example.com"},
                           %{"username" => "chetops",
                             "email_address" => "chetops@example.com"}]}
    # TODO: Fix newlines here
    attachments = [
      """
      *Username:* cog
      *First Name:* Cog

      *Email:* cog@example.com
      """,
      """
      *Username:* sprocket

      *Last Name:* McCog
      *Email:* sprocket@example.com
      """,
      """
      *Username:* chetops

      *Email:* chetops@example.com
      """
    ] |> Enum.map(&String.strip/1)

    assert_rendered_template(:slack, :embedded, "user-list", data, {"", attachments})
  end
end

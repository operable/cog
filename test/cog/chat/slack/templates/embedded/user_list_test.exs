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
    expected = """
    ```+----------+------------+-----------+----------------------+
    | Username | First Name | Last Name | Email                |
    +----------+------------+-----------+----------------------+
    | cog      | Cog        | McCog     | cog@example.com      |
    | sprocket | Sprocket   | McCog     | sprocket@example.com |
    | chetops  | Chet       | Ops       | chetops@example.com  |
    +----------+------------+-----------+----------------------+
    ```
    """ |> String.strip

    assert_rendered_template(:slack, :embedded, "user-list", data, expected)
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
    expected = """
    ```+----------+------------+-----------+----------------------+
    | Username | First Name | Last Name | Email                |
    +----------+------------+-----------+----------------------+
    | cog      | Cog        |           | cog@example.com      |
    | sprocket |            | McCog     | sprocket@example.com |
    | chetops  |            |           | chetops@example.com  |
    +----------+------------+-----------+----------------------+
    ```
    """ |> String.strip

    assert_rendered_template(:slack, :embedded, "user-list", data, expected)
  end
end

defmodule Cog.Chat.HipChat.Templates.Embedded.UserListTest do
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
    cog<br/>
    sprocket<br/>
    chetops
    """ |> String.replace("\n", "")

    assert_rendered_template(:hipchat, :embedded, "user-list", data, expected)
  end
end

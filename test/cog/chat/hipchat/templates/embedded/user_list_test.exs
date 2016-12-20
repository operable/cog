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
    <strong>Username:</strong> cog<br/>
    <strong>First Name:</strong> Cog<br/>
    <strong>Last Name:</strong> McCog<br/>
    <strong>Email:</strong> cog@example.com<br/>
    <br/>
    <strong>Username:</strong> sprocket<br/>
    <strong>First Name:</strong> Sprocket<br/>
    <strong>Last Name:</strong> McCog<br/>
    <strong>Email:</strong> sprocket@example.com<br/>
    <br/>
    <strong>Username:</strong> chetops<br/>
    <strong>First Name:</strong> Chet<br/>
    <strong>Last Name:</strong> Ops<br/>
    <strong>Email:</strong> chetops@example.com
    """ |> String.replace("\n", "")

    assert_rendered_template(:hipchat, :embedded, "user-list", data, expected)
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
    <strong>Username:</strong> cog<br/>
    <strong>First Name:</strong> Cog<br/>
    <br/>
    <strong>Email:</strong> cog@example.com<br/>
    <br/>
    <strong>Username:</strong> sprocket<br/>
    <br/>
    <strong>Last Name:</strong> McCog<br/>
    <strong>Email:</strong> sprocket@example.com<br/>
    <br/>
    <strong>Username:</strong> chetops<br/>
    <br/>
    <strong>Email:</strong> chetops@example.com
    """ |> String.replace("\n", "")

    assert_rendered_template(:hipchat, :embedded, "user-list", data, expected)
  end
end

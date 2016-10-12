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
    <table>
    <th><td>Username</td><td>First Name</td><td>Last Name</td><td>Email</td></th>
    <tr><td>cog</td><td>Cog</td><td>McCog</td><td>cog@example.com</td></tr>
    <tr><td>sprocket</td><td>Sprocket</td><td>McCog</td><td>sprocket@example.com</td></tr>
    <tr><td>chetops</td><td>Chet</td><td>Ops</td><td>chetops@example.com</td></tr>
    </table>
    """

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
    <table>
    <th><td>Username</td><td>First Name</td><td>Last Name</td><td>Email</td></th>
    <tr><td>cog</td><td>Cog</td><td></td><td>cog@example.com</td></tr>
    <tr><td>sprocket</td><td></td><td>McCog</td><td>sprocket@example.com</td></tr>
    <tr><td>chetops</td><td></td><td></td><td>chetops@example.com</td></tr>
    </table>
    """

    assert_rendered_template(:hipchat, :embedded, "user-list", data, expected)
  end
end

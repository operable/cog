defmodule Cog.Chat.HipChat.Templates.Embedded.UserListHandlesTest do
  use Cog.TemplateCase

  test "user-list-handles template" do
    data = %{"results" => [%{"username" => "cog",
                             "handle" => "cog"},
                           %{"username" => "sprocket",
                             "handle" => "spacely"},
                           %{"username" => "chetops",
                             "handle" => "ChetOps"}]}
    expected = """
    <table>
    <th><td>Username</td><td>Handle</td></th>
    <tr><td>cog</td><td>@cog</td></tr>
    <tr><td>sprocket</td><td>@spacely</td></tr>
    <tr><td>chetops</td><td>@ChetOps</td></tr>
    </table>
    """

    assert_rendered_template(:hipchat, :embedded, "user-list-handles", data, expected)
  end

end

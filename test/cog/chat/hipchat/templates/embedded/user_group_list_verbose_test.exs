defmodule Cog.Chat.HipChat.Templates.Embedded.UserGroupListVerboseTest do
  use Cog.TemplateCase

    test "user-group-list-verbose template with multiple inputs" do
    data = %{"results" => [%{"name" => "foo",
                             "id" => "123",
                             "roles" => [%{"name" => "heroku-admin"},
                                         %{"name" => "aws-admin"}],
                             "members" => [%{"username" => "larry"},
                                           %{"username" => "moe"},
                                           %{"username" => "curly"}]},
                           %{"name" => "bar",
                             "id" => "456",
                             "roles" => [%{"name" => "bar-admin"}],
                             "members" => [%{"username" => "sterling"},
                                           %{"username" => "lana"},
                                           %{"username" => "pam"}]},
                          %{"name" => "baz",
                             "id" => "789",
                             "roles" => [%{"name" => "baz-admin"}],
                             "members" => [%{"username" => "tina"},
                                           %{"username" => "gene"},
                                           %{"username" => "louise"}]}]}

    expected = """
    <table>
    <th><td>Name</td><td>ID</td><td>Roles</td><td>Members</td></th>
    <tr><td>foo</td><td>123</td><td>heroku-admin, aws-admin</td><td>larry, moe, curly</td></tr>
    <tr><td>bar</td><td>456</td><td>bar-admin</td><td>sterling, lana, pam</td></tr>
    <tr><td>baz</td><td>789</td><td>baz-admin</td><td>tina, gene, louise</td></tr>
    </table>
    """

    assert_rendered_template(:hipchat, :embedded, "user-group-list-verbose", data, expected)
  end

end

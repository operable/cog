defmodule Cog.Chat.HipChat.Templates.Embedded.UserGroupInfoTest do
  use Cog.TemplateCase

  test "user-group-info template" do
    data = %{"results" => [%{"name" => "foo",
                             "id" => "123",
                             "roles" => [%{"name" => "heroku-admin"},
                                         %{"name" => "aws-admin"}],
                             "members" => [%{"username" => "larry"},
                                           %{"username" => "moe"},
                                           %{"username" => "curly"}]}]}

    expected = "<strong>Name</strong>: foo<br/>" <>
      "<strong>ID</strong>: 123<br/>" <>
      "<strong>Roles</strong>: heroku-admin, aws-admin<br/>" <>
      "<strong>Members</strong>: larry, moe, curly"

    assert_rendered_template(:hipchat, :embedded, "user-group-info", data, expected)
  end

  test "user-group-info template with multiple inputs" do
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
    <pre>+------+-----+-------------------------+---------------------+
    | Name | ID  | Roles                   | Members             |
    +------+-----+-------------------------+---------------------+
    | foo  | 123 | heroku-admin, aws-admin | larry, moe, curly   |
    | bar  | 456 | bar-admin               | sterling, lana, pam |
    | baz  | 789 | baz-admin               | tina, gene, louise  |
    +------+-----+-------------------------+---------------------+
    </pre>\
    """

    assert_rendered_template(:hipchat, :embedded, "user-group-info", data, expected)
  end

end

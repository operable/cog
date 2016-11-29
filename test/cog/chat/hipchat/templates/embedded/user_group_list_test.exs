defmodule Cog.Chat.HipChat.Templates.Embedded.UserGroupListTest do
  use Cog.TemplateCase

  test "user-group-list template" do
    data = %{"results" => [%{"name" => "foo"},
                           %{"name" => "bar"},
                           %{"name" => "baz"}]}

    expected = """
    <pre>+------+
    | Name |
    +------+
    | foo  |
    | bar  |
    | baz  |
    +------+
    </pre>\
    """

    assert_rendered_template(:hipchat, :embedded, "user-group-list", data, expected)
  end

end

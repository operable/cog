defmodule Cog.Chat.HipChat.Templates.Embedded.PermissionListTest do
  use Cog.TemplateCase

  test "permission-list template" do
    data = %{"results" => [%{"bundle" => "site", "name" => "foo"},
                           %{"bundle" => "site", "name" => "bar"},
                           %{"bundle" => "site", "name" => "baz"}]}

    expected = """
    <pre>+--------+------+
    | Bundle | Name |
    +--------+------+
    | site   | foo  |
    | site   | bar  |
    | site   | baz  |
    +--------+------+
    </pre>\
    """

    assert_rendered_template(:hipchat, :embedded, "permission-list", data, expected)
  end

end

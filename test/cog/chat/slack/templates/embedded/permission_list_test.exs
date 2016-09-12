defmodule Cog.Chat.Slack.Templates.Embedded.PermissionListTest do
  use Cog.TemplateCase

  test "permission-list template" do
    data = %{"results" => [%{"bundle" => "site", "name" => "foo"},
                           %{"bundle" => "site", "name" => "bar"},
                           %{"bundle" => "site", "name" => "baz"}]}

    expected = """
    ```+--------+------+
    | Bundle | Name |
    +--------+------+
    | site   | foo  |
    | site   | bar  |
    | site   | baz  |
    +--------+------+
    ```
    """ |> String.strip

    assert_rendered_template(:embedded, "permission-list", data, expected)
  end

end

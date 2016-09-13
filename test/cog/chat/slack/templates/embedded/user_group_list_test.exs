defmodule Cog.Chat.Slack.Templates.Embedded.UserGroupListTest do
  use Cog.TemplateCase

  test "user-group-list template" do
    data = %{"results" => [%{"name" => "foo"},
                           %{"name" => "bar"},
                           %{"name" => "baz"}]}

    expected = """
    ```+------+
    | Name |
    +------+
    | foo  |
    | bar  |
    | baz  |
    +------+
    ```
    """ |> String.strip

    assert_rendered_template(:slack, :embedded, "user-group-list", data, expected)
  end

end

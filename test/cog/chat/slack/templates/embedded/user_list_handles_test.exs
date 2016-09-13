defmodule Cog.Chat.Slack.Templates.Embedded.UserListHandlesTest do
  use Cog.TemplateCase

  test "user-list-handles template" do
    data = %{"results" => [%{"username" => "cog",
                             "handle" => "cog"},
                           %{"username" => "sprocket",
                             "handle" => "spacely"},
                           %{"username" => "chetops",
                             "handle" => "ChetOps"}]}
    expected = """
    ```+----------+----------+
    | Username | Handle   |
    +----------+----------+
    | cog      | @cog     |
    | sprocket | @spacely |
    | chetops  | @ChetOps |
    +----------+----------+
    ```
    """ |> String.strip

    assert_rendered_template(:slack, :embedded, "user-list-handles", data, expected)
  end

end

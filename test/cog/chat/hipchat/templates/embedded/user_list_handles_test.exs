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
    <pre>+----------+----------+
    | Username | Handle   |
    +----------+----------+
    | cog      | @cog     |
    | sprocket | @spacely |
    | chetops  | @ChetOps |
    +----------+----------+
    </pre>\
    """

    assert_rendered_template(:hipchat, :embedded, "user-list-handles", data, expected)
  end

end

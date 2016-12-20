defmodule Cog.Chat.HipChat.Templates.Embedded.UserListHandlesTest do
  use Cog.TemplateCase

  test "user-list-handles template" do
    data = %{"results" => [%{"username" => "cog",
                             "handle" => "cog",
                             "chat_provider" => %{"name" => "slack"}},
                           %{"username" => "sprocket",
                             "handle" => "spacely",
                             "chat_provider" => %{"name" => "slack"}},
                           %{"username" => "chetops",
                             "handle" => "ChetOps",
                             "chat_provider" => %{"name" => "hipchat"}}]}

    expected = """
    <strong>Username:</strong> cog<br/>
    <strong>Handle:</strong> @cog<br/>
    <strong>Chat Provider:</strong> slack<br/>
    <br/>
    <strong>Username:</strong> sprocket<br/>
    <strong>Handle:</strong> @spacely<br/>
    <strong>Chat Provider:</strong> slack<br/>
    <br/>
    <strong>Username:</strong> chetops<br/>
    <strong>Handle:</strong> @ChetOps<br/>
    <strong>Chat Provider:</strong> hipchat
    """ |> String.replace("\n", "")

    assert_rendered_template(:hipchat, :embedded, "user-list-handles", data, expected)
  end

end

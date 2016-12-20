defmodule Cog.Chat.Slack.Templates.Embedded.UserListHandlesTest do
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
    attachments = [
      """
      *Username:* cog
      *Handle:* @cog
      *Chat Provider:* slack
      """,
      """
      *Username:* sprocket
      *Handle:* @spacely
      *Chat Provider:* slack
      """,
      """
      *Username:* chetops
      *Handle:* @ChetOps
      *Chat Provider:* hipchat
      """,
    ] |> Enum.map(&String.rstrip/1)

    assert_rendered_template(:slack, :embedded, "user-list-handles", data, {"", attachments})
  end

end

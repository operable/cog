defmodule Cog.Chat.Slack.Templates.Embedded.RelayListTest do
  use Cog.TemplateCase

  test "relay-list template" do
    data = %{"results" => [%{"name" => "relay_one",
                             "status" => "enabled"},
                           %{"name" => "relay_two",
                             "status" => "disabled"},
                           %{"name" => "relay_three",
                             "status" => "enabled"}]}

    attachments = [
      """
      *Name:* relay_one
      *Status:* enabled
      """,
      """
      *Name:* relay_two
      *Status:* disabled
      """,
      """
      *Name:* relay_three
      *Status:* enabled
      """,
    ] |> Enum.map(&String.strip/1)

    assert_rendered_template(:slack, :embedded, "relay-list", data, {"", attachments})
  end


end

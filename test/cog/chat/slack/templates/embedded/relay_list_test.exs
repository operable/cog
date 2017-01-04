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
      "relay_one (enabled)",
      "relay_two (disabled)",
      "relay_three (enabled)"
    ]

    assert_rendered_template(:slack, :embedded, "relay-list", data, {"", attachments})
  end


end

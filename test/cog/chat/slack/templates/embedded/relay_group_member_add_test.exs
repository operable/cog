defmodule Cog.Chat.Slack.Templates.Embedded.RelayGroupMemberAddTest do
  use Cog.TemplateCase

  test "relay-group-member-add template" do
    data = %{"results" => [%{"name" => "testgroup",
                             "relays_added" => ["relay1",
                                                "relay2"]}]}

    expected = """
    Added relay 'relay1' to relay group 'testgroup'
    Added relay 'relay2' to relay group 'testgroup'
    """ |> String.strip()

    assert_rendered_template(:slack, :embedded, "relay-group-member-add", data, expected)
  end
end

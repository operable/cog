defmodule Cog.Chat.Slack.Templates.Embedded.RelayGroupMemberRemoveTest do
  use Cog.TemplateCase

  test "relay-group-member-remove template" do
    data = %{"results" => [%{"name" => "testgroup",
                             "relays_removed" => ["relay1",
                                                  "relay2"]}]}

    expected = """
    Removed relay 'relay1' from relay group 'testgroup'
    Removed relay 'relay2' from relay group 'testgroup'
    """ |> String.strip()

    assert_rendered_template(:slack, :embedded, "relay-group-member-remove", data, expected)
  end
end

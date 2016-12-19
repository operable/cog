defmodule Cog.Chat.Slack.Templates.Embedded.RelayGroupMemberUnassignTest do
  use Cog.TemplateCase

  test "relay-group-member-unassign template" do
    data = %{"results" => [%{"name" => "testgroup",
                             "bundles_unassigned" => ["bundle1",
                                                      "bundle2"]}]}

    expected = """
    Unassigned bundle 'bundle1' from relay group 'testgroup'
    Unassigned bundle 'bundle2' from relay group 'testgroup'
    """ |> String.strip()

    assert_rendered_template(:slack, :embedded, "relay-group-member-unassign", data, expected)
  end
end

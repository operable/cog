defmodule Cog.Chat.Slack.Templates.Embedded.GroupMemberRemoveTest do
  use Cog.TemplateCase

  test "group-member-remove template" do
    data = %{"results" => [%{"name" => "testgroup",
                             "members_removed" => ["member1",
                                                   "member2"]}]}

    expected = """
    Removed user 'member1' from group 'testgroup'
    Removed user 'member2' from group 'testgroup'
    """ |> String.strip()

    assert_rendered_template(:slack, :embedded, "group-member-remove", data, expected)
  end
end

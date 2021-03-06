defmodule Cog.Chat.Slack.Templates.Embedded.GroupMemberAddTest do
  use Cog.TemplateCase

  test "group-member-add template" do
    data = %{"results" => [%{"name" => "testgroup",
                             "members_added" => ["member1",
                                                 "member2"]}]}
    expected = """
    Added user 'member1' to group 'testgroup'
    Added user 'member2' to group 'testgroup'
    """ |> String.strip()

    assert_rendered_template(:slack, :embedded, "group-member-add", data, expected)
  end
end

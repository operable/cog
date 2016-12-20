defmodule Cog.Chat.Slack.Templates.Embedded.GroupInfoTest do
  use Cog.TemplateCase

  test "group-info template" do
    data = %{"results" => [%{"id" => "aaaa-bbbb-cccc-dddd-eeee-ffff",
                             "name" => "testgroup",
                             "roles" => [%{"name" => "role1"},
                                         %{"name" => "role2"}],
                             "members" => [%{"username" => "bob"},
                                           %{"username" => "bill"}]}]}
    expected = """
    *Name:* testgroup
    *ID:* aaaa-bbbb-cccc-dddd-eeee-ffff
    *Roles:* role1, role2
    *Members:* bob, bill
    """ |> String.strip()

    assert_rendered_template(:slack, :embedded, "group-info", data, expected)
  end
end

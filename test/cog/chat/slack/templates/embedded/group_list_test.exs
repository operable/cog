defmodule Cog.Chat.Slack.Templates.Embedded.GroupListTest do
  use Cog.TemplateCase

  test "group-list template" do
    data = %{"results" => [%{"name" => "testgroup1"},
                           %{"name" => "testgroup2"},
                           %{"name" => "testgroup3"}]}
    expected = """
    testgroup1
    testgroup2
    testgroup3
    """ |> String.strip()

    assert_rendered_template(:slack, :embedded, "group-list", data, expected)
  end

  test "group-list verbose template" do
    data = %{"results" => [%{"name" => "testgroup1",
                             "id" => "aaaa-bbbb-cccc-dddd-eeee-ffff",
                             "roles" => [%{"name" => "role1"},
                                         %{"name" => "role2"}],
                             "members" => [%{"username" => "member1"},
                                           %{"username" => "member2"}]},
                           %{"name" => "testgroup2",
                             "id" => "aaaa-bbbb-cccc-dddd-eeee-ffff",
                             "roles" => [%{"name" => "role1"},
                                         %{"name" => "role2"}],
                             "members" => [%{"username" => "member1"},
                                           %{"username" => "member2"}]},
                            %{"name" => "testgroup3",
                             "id" => "aaaa-bbbb-cccc-dddd-eeee-ffff",
                             "roles" => [%{"name" => "role1"},
                                         %{"name" => "role2"}],
                             "members" => [%{"username" => "member1"},
                                           %{"username" => "member2"}]}]}
    attachments = [
      """
      *Name:* testgroup1
      *ID:* aaaa-bbbb-cccc-dddd-eeee-ffff
      *Roles:* role1, role2
      *Members:* member1, member2
      """,
      """
      *Name:* testgroup2
      *ID:* aaaa-bbbb-cccc-dddd-eeee-ffff
      *Roles:* role1, role2
      *Members:* member1, member2
      """,
      """
      *Name:* testgroup3
      *ID:* aaaa-bbbb-cccc-dddd-eeee-ffff
      *Roles:* role1, role2
      *Members:* member1, member2
      """
    ] |> Enum.map(&String.strip/1)

    assert_rendered_template(:slack, :embedded, "group-list-verbose", data, {"", attachments})
  end

end

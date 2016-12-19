defmodule Cog.Chat.HipChat.Templates.Embedded.GroupInfoTest do
  use Cog.TemplateCase

  test "group-info template" do
    data = %{"results" => [%{"id" => "aaaa-bbbb-cccc-dddd-eeee-ffff",
                             "name" => "testgroup",
                             "roles" => [%{"name" => "role1"},
                                         %{"name" => "role2"}],
                             "members" => [%{"username" => "bob"},
                                           %{"username" => "bill"}]}]}
    expected = """
    <strong>Name:</strong> testgroup<br/>\
    <strong>ID:</strong> aaaa-bbbb-cccc-dddd-eeee-ffff<br/>\
    <strong>Roles:</strong> role1, role2<br/>\
    <strong>Members:</strong> bob, bill
    """ |> String.strip()

    assert_rendered_template(:hipchat, :embedded, "group-info", data, expected)
  end
end

defmodule Cog.Chat.HipChat.Templates.Embedded.GroupListVerboseTest do
  use Cog.TemplateCase

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
    expected = """
      <strong>Name:</strong> testgroup1<br/>\
      <strong>ID:</strong> aaaa-bbbb-cccc-dddd-eeee-ffff<br/>\
      <strong>Roles:</strong> role1, role2<br/>\
      <strong>Members:</strong> member1, member2<br/>\
      <br/>\
      <strong>Name:</strong> testgroup2<br/>\
      <strong>ID:</strong> aaaa-bbbb-cccc-dddd-eeee-ffff<br/>\
      <strong>Roles:</strong> role1, role2<br/>\
      <strong>Members:</strong> member1, member2<br/>\
      <br/>\
      <strong>Name:</strong> testgroup3<br/>\
      <strong>ID:</strong> aaaa-bbbb-cccc-dddd-eeee-ffff<br/>\
      <strong>Roles:</strong> role1, role2<br/>\
      <strong>Members:</strong> member1, member2
      """ |> String.strip()

    assert_rendered_template(:hipchat, :embedded, "group-list-verbose", data, expected)
  end

end

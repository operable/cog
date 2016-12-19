defmodule Cog.Chat.HipChat.Templates.Embedded.GroupRoleRemoveTest do
  use Cog.TemplateCase

  test "group-role-remove template" do
    data = %{"results" => [%{"name" => "testgroup",
                             "roles_removed" => ["role1",
                                                 "role2"]}]}

    expected = """
    Removed role 'role1' from group 'testgroup'<br/>\
    Removed role 'role2' from group 'testgroup'
    """ |> String.strip()

    assert_rendered_template(:hipchat, :embedded, "group-role-remove", data, expected)
  end

end

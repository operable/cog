defmodule Cog.Chat.HipChat.Templates.Embedded.RoleListTest do
  use Cog.TemplateCase

  test "role-list template" do
    data = %{"results" => [%{"name" => "foo"},
                           %{"name" => "bar"},
                           %{"name" => "baz",
                             "permissions" => [%{"name": "manage_users",
                                                 "id": "a598628c-c2d8-4ace-9abc-29467e35f5e0",
                                                 "bundle": "operable"}]}]}

    expected = """
    foo (0 permissions)<br/>
    bar (0 permissions)<br/>
    baz (1 permissions)
    """ |> String.replace("\n", "")

    assert_rendered_template(:hipchat, :embedded, "role-list", data, expected)
  end

end

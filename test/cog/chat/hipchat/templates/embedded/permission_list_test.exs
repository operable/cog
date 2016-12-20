defmodule Cog.Chat.HipChat.Templates.Embedded.PermissionListTest do
  use Cog.TemplateCase

  test "permission-list template" do
    data = %{"results" => [%{"bundle" => "site", "name" => "foo"},
                           %{"bundle" => "site", "name" => "bar"},
                           %{"bundle" => "site", "name" => "baz"}]}

    expected = """
    <strong>Name:</strong> foo<br/>
    <strong>Bundle:</strong> site<br/>
    <br/>
    <strong>Name:</strong> bar<br/>
    <strong>Bundle:</strong> site<br/>
    <br/>
    <strong>Name:</strong> baz<br/>
    <strong>Bundle:</strong> site
    """ |> String.replace("\n", "")

    assert_rendered_template(:hipchat, :embedded, "permission-list", data, expected)
  end

end

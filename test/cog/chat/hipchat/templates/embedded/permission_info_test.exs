defmodule Cog.Chat.HipChat.Templates.Embedded.PermissionInfoTest do
  use Cog.TemplateCase

  test "permission-info template" do
    data = %{"results" => [%{"id" => "123", "bundle" => "site", "name" => "foo"}]}

    expected = """
    <strong>Name:</strong> site:foo<br/>
    <strong>ID:</strong> 123
    """ |> String.replace("\n", "")

    assert_rendered_template(:hipchat, :embedded, "permission-info", data, expected)
  end
end

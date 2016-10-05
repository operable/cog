defmodule Cog.Chat.HipChat.Templates.Embedded.RoleInfoTest do
  use Cog.TemplateCase

  test "role-info template with one input" do
    data = %{"results" => [%{"id" => "123",
                             "name" => "foo",
                             "permissions" => [%{"bundle" => "site", "name" => "foo"}]}]}

    expected = "<strong>ID</strong>: 123<br/>" <>
      "<strong>Name</strong>: foo<br/>" <>
      "<strong>Permissions</strong>: site:foo"

    assert_rendered_template(:hipchat, :embedded, "role-info", data, expected)
  end

  test "role-info template with multiple inputs" do
    data = %{"results" => [%{"id" => "123",
                             "name" => "foo",
                             "permissions" => [%{"bundle" => "site", "name" => "foo"}]},
                           %{"id" => "456",
                             "name" => "bar",
                             "permissions" => [%{"bundle" => "site", "name" => "foo"},
                                               %{"bundle" => "operable", "name" => "blah"}]},
                           %{"id" => "789",
                             "name" => "baz",
                             "permissions" => [%{"bundle" => "site", "name" => "foo"}]}

                          ]}

    expected = """
    <table>
    <th><td>Name</td><td>ID</td><td>Permissions</td></th>
    <tr><td>foo</td><td>123</td><td>site:foo</td></tr>
    <tr><td>bar</td><td>456</td><td>site:foo, operable:blah</td></tr>
    <tr><td>baz</td><td>789</td><td>site:foo</td></tr>
    </table>
    """

    assert_rendered_template(:hipchat, :embedded, "role-info", data, expected)
  end


end

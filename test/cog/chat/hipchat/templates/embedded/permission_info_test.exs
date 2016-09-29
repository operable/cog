defmodule Cog.Chat.HipChat.Templates.Embedded.PermissionInfoTest do
  use Cog.TemplateCase

  test "permission-info template" do
    data = %{"results" => [%{"id" => "123", "bundle" => "site", "name" => "foo"}]}

    expected = "<strong>ID</strong>: 123<br/>" <>
      "<strong>Bundle</strong>: site<br/>" <>
      "<strong>Name</strong>: foo"

    assert_rendered_template(:hipchat, :embedded, "permission-info", data, expected)
  end

  test "permission-info template with multiple inputs" do
    data = %{"results" => [%{"id" => "123", "bundle" => "foo_bundle", "name" => "foo"},
                           %{"id" => "456", "bundle" => "bar_bundle", "name" => "bar"},
                           %{"id" => "789", "bundle" => "baz_bundle", "name" => "baz"}]}

    expected = """
    <table>
    <th><td>Bundle</td><td>Name</td><td>ID</td></th>
    <tr><td>foo_bundle</td><td>foo</td><td>123</td></tr>
    <tr><td>bar_bundle</td><td>bar</td><td>456</td></tr>
    <tr><td>baz_bundle</td><td>baz</td><td>789</td></tr>
    </table>
    """

    assert_rendered_template(:hipchat, :embedded, "permission-info", data, expected)
  end


end

defmodule Cog.Chat.HipChat.Templates.Embedded.BundleListTest do
  use Cog.TemplateCase

  test "bundle-list template" do
    data = %{"results" => [%{"name" => "test_bundle1",
                             "enabled_version" => %{"version" => "1.0.0"}},
                           %{"name" => "test_bundle2",
                             "enabled_version" => %{"version" => "2.0.0"}},
                           %{"name" => "test_bundle3",
                             "enabled_version" => %{"version" => "3.0.0"}},
                           %{"name" => "test_bundle4",
                             "enabled_version" => %{"version" => "4.0.0"}}]}

    expected = """
    <table>
    <th><td>Name</td><td>Enabled Version</td></th>
    <tr><td>test_bundle1</td><td>1.0.0</td></tr>
    <tr><td>test_bundle2</td><td>2.0.0</td></tr>
    <tr><td>test_bundle3</td><td>3.0.0</td></tr>
    <tr><td>test_bundle4</td><td>4.0.0</td></tr>
    </table>
    """

    assert_rendered_template(:hipchat, :embedded, "bundle-list", data, expected)
  end

  test "handles disabled bundles properly" do
    data = %{"results" => [%{"name" => "test_bundle1"},
                           %{"name" => "test_bundle2",
                             "enabled_version" => %{"version" => "2.0.0"}}]}


    expected = """
    <table>
    <th><td>Name</td><td>Enabled Version</td></th>
    <tr><td>test_bundle1</td><td></td></tr>
    <tr><td>test_bundle2</td><td>2.0.0</td></tr>
    </table>
    """

    assert_rendered_template(:hipchat, :embedded, "bundle-list", data, expected)
  end

end

defmodule Cog.Chat.HipChat.Templates.Embedded.BundleVersionsTest do
  use Cog.TemplateCase

  test "bundle-versions template" do
    data = %{"results" => [%{"name" => "test_bundle1",
                             "version" => "1.0.0",
                             "enabled" => true},
                           %{"name" => "test_bundle1",
                             "version" => "0.0.9",
                             "enabled" => false},
                           %{"name" => "test_bundle1",
                             "version" => "0.0.8",
                             "enabled" => false},
                           %{"name" => "test_bundle1",
                             "version" => "0.0.7",
                             "enabled" => false}]}
    expected = """
    <table>
    <th><td>Version</td><td>Enabled?</td></th>
    <tr><td>1.0.0</td><td>true</td></tr>
    <tr><td>0.0.9</td><td>false</td></tr>
    <tr><td>0.0.8</td><td>false</td></tr>
    <tr><td>0.0.7</td><td>false</td></tr>
    </table>
    """

    assert_rendered_template(:hipchat, :embedded, "bundle-versions", data, expected)
  end

end

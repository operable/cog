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
    <strong>Version:</strong> 1.0.0<br/>
    <strong>Enabled:</strong> true<br/>
    <br/>
    <strong>Version:</strong> 0.0.9<br/>
    <strong>Enabled:</strong> false<br/>
    <br/>
    <strong>Version:</strong> 0.0.8<br/>
    <strong>Enabled:</strong> false<br/>
    <br/>
    <strong>Version:</strong> 0.0.7<br/>
    <strong>Enabled:</strong> false
    """ |> String.replace("\n", "")

    assert_rendered_template(:hipchat, :embedded, "bundle-versions", data, expected)
  end

end

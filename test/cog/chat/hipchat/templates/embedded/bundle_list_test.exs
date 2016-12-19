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
    <strong>Name:</strong> test_bundle1<br/>
    <strong>Version Enabled:</strong> 1.0.0<br/>
    <br/>
    <strong>Name:</strong> test_bundle2<br/>
    <strong>Version Enabled:</strong> 2.0.0<br/>
    <br/>
    <strong>Name:</strong> test_bundle3<br/>
    <strong>Version Enabled:</strong> 3.0.0<br/>
    <br/>
    <strong>Name:</strong> test_bundle4<br/>
    <strong>Version Enabled:</strong> 4.0.0
    """ |> String.replace("\n", "")

    assert_rendered_template(:hipchat, :embedded, "bundle-list", data, expected)
  end

  test "handles disabled bundles properly" do
    data = %{"results" => [%{"name" => "test_bundle1"},
                           %{"name" => "test_bundle2",
                             "enabled_version" => %{"version" => "2.0.0"}}]}


    expected = """
    <strong>Name:</strong> test_bundle1<br/>
    <strong>Version Enabled:</strong> Disabled<br/>
    <br/>
    <strong>Name:</strong> test_bundle2<br/>
    <strong>Version Enabled:</strong> 2.0.0
    """ |> String.replace("\n", "")

    assert_rendered_template(:hipchat, :embedded, "bundle-list", data, expected)
  end

end

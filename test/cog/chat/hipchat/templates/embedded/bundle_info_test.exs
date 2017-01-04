defmodule Cog.Chat.HipChat.Templates.Embedded.BundleInfoTest do
  use Cog.TemplateCase

  test "bundle-info template" do
    data = %{"results" => [%{"id" => "aaaa-bbbb-cccc-dddd-eeee-ffff",
                             "name" => "my_bundle",
                             "versions" => [%{"version" => "0.0.1"},
                                            %{"version" => "0.0.2"},
                                            %{"version" => "0.0.3"}],
                             "enabled_version" => %{"version" => "0.0.3"},
                             "relay_groups" => [%{"name" => "preprod"},
                                                %{"name" => "prod"}]}]}

    expected = """
    <strong>ID:</strong> aaaa-bbbb-cccc-dddd-eeee-ffff<br/>
    <strong>Name:</strong> my_bundle<br/>
    <strong>Relay Groups:</strong> preprod, prod<br/>
    <strong>Versions:</strong> 0.0.1, 0.0.2, 0.0.3<br/>
    <strong>Version Enabled:</strong> 0.0.3
    """ |> String.replace("\n", "")

    assert_rendered_template(:hipchat, :embedded, "bundle-info", data, expected)
  end

  test "bundle-info with incompatible versions template" do
    data = %{"results" => [%{"id" => "aaaa-bbbb-cccc-dddd-eeee-ffff",
                             "name" => "my_bundle",
                             "versions" => [%{"version" => "0.0.2"},
                                            %{"version" => "0.0.3"},
                                            %{"version" => "0.0.4"}],
                             "incompatible_versions" => [%{"version" => "0.0.1"}],
                             "enabled_version" => %{"version" => "0.0.3"},
                             "relay_groups" => [%{"name" => "preprod"},
                                                %{"name" => "prod"}]}]}

    expected = """
    <strong>ID:</strong> aaaa-bbbb-cccc-dddd-eeee-ffff<br/>
    <strong>Name:</strong> my_bundle<br/>
    <strong>Relay Groups:</strong> preprod, prod<br/>
    <strong>Versions:</strong> 0.0.2, 0.0.3, 0.0.4<br/>
    <strong>Version Enabled:</strong> 0.0.3<br/>
    <strong>Incompatible Versions:</strong> 0.0.1
    """ |> String.replace("\n", "")

    assert_rendered_template(:hipchat, :embedded, "bundle-info", data, expected)
  end

end

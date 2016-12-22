defmodule Cog.Chat.Slack.Templates.Embedded.BundleInfoTest do
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
    *ID:* aaaa-bbbb-cccc-dddd-eeee-ffff
    *Name:* my_bundle
    *Versions:* 0.0.1, 0.0.2, 0.0.3
    *Version Enabled:* 0.0.3
    *Relay Groups:* preprod, prod
    """ |> String.strip

    assert_rendered_template(:slack, :embedded, "bundle-info", data, expected)
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
    *ID:* aaaa-bbbb-cccc-dddd-eeee-ffff
    *Name:* my_bundle
    *Versions:* 0.0.2, 0.0.3, 0.0.4
    *Incompatible Versions:* 0.0.1
    *Version Enabled:* 0.0.3
    *Relay Groups:* preprod, prod
    """ |> String.strip

    assert_rendered_template(:slack, :embedded, "bundle-info", data, expected)
  end

end

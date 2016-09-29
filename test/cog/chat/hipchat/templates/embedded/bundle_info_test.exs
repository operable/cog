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
    expected = "ID: aaaa-bbbb-cccc-dddd-eeee-ffff<br/>" <>
      "Name: my_bundle<br/>" <>
      "Versions: 0.0.1<br/>" <>
      "0.0.2<br/>" <>
      "0.0.3<br/>" <>
      "Enabled Version: 0.0.3<br/>" <>
      "Relay Groups: preprod<br/>" <>
      "prod"
    assert_rendered_template(:hipchat, :embedded, "bundle-info", data, expected)
  end

end

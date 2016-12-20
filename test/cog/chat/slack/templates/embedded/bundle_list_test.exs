defmodule Cog.Chat.Slack.Templates.Embedded.BundleListTest do
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

    attachments = [
      """
      *Name:* test_bundle1
      *Version Enabled:* 1.0.0
      """,
      """
      *Name:* test_bundle2
      *Version Enabled:* 2.0.0
      """,
      """
      *Name:* test_bundle3
      *Version Enabled:* 3.0.0
      """,
      """
      *Name:* test_bundle4
      *Version Enabled:* 4.0.0
      """
    ] |> Enum.map(&String.strip/1)

    assert_rendered_template(:slack, :embedded, "bundle-list", data, {"", attachments})
  end

  test "handles disabled bundles properly" do
    data = %{"results" => [%{"name" => "test_bundle1"},
                           %{"name" => "test_bundle2",
                             "enabled_version" => %{"version" => "2.0.0"}}]}


    attachments = [
      """
      *Name:* test_bundle1
      *Version Enabled:* Disabled
      """,
      """
      *Name:* test_bundle2
      *Version Enabled:* 2.0.0
      """,
    ] |> Enum.map(&String.strip/1)

    assert_rendered_template(:slack, :embedded, "bundle-list", data, {"", attachments})
  end

end

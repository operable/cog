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

    attachments = ["test_bundle1 (1.0.0)",
                   "test_bundle2 (2.0.0)",
                   "test_bundle3 (3.0.0)",
                   "test_bundle4 (4.0.0)"]

    assert_rendered_template(:slack, :embedded, "bundle-list", data, {"", attachments})
  end

  test "handles disabled bundles properly" do
    data = %{"results" => [%{"name" => "test_bundle1"},
                           %{"name" => "test_bundle2",
                             "enabled_version" => %{"version" => "2.0.0"}}]}



    attachments = ["test_bundle1 (disabled)",
                   "test_bundle2 (2.0.0)"]

    assert_rendered_template(:slack, :embedded, "bundle-list", data, {"", attachments})
  end

end

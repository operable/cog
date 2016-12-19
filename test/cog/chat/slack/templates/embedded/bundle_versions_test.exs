defmodule Cog.Chat.Slack.Templates.Embedded.BundleVersionsTest do
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

    attachments = [
      """
      *Version:* 1.0.0
      *Enabled:* true
      """,
      """
      *Version:* 0.0.9
      *Enabled:* false
      """,
      """
      *Version:* 0.0.8
      *Enabled:* false
      """,
      """
      *Version:* 0.0.7
      *Enabled:* false
      """
    ] |> Enum.map(&String.strip/1)

    assert_rendered_template(:slack, :embedded, "bundle-versions", data, {"", attachments})
  end

end

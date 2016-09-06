defmodule Cog.Chat.Slack.Templates.Embedded.PermissionTest do
  use Cog.TemplateCase

  test "permission-grant template" do
    data = %{"results" => [%{"permission" => %{"bundle" => "site",
                                               "name" => "foo"},
                             "role" => %{"name" => "ops"}}]}

    expected = "Granted permission ```site:foo``` to role ```ops```"
    assert_rendered_template(:embedded, "permission-grant", data, expected)
  end

end

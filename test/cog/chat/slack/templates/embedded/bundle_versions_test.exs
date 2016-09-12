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
    expected = """
    ```+---------+----------+
    | Version | Enabled? |
    +---------+----------+
    | 1.0.0   | true     |
    | 0.0.9   | false    |
    | 0.0.8   | false    |
    | 0.0.7   | false    |
    +---------+----------+
    ```
    """ |> String.strip

    assert_rendered_template(:embedded, "bundle-versions", data, expected)
  end

end

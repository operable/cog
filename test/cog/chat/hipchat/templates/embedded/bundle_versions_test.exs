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
    1.0.0 (enabled)<br/>
    0.0.9 (disabled)<br/>
    0.0.8 (disabled)<br/>
    0.0.7 (disabled)
    """ |> String.replace("\n", "")

    assert_rendered_template(:hipchat, :embedded, "bundle-versions", data, expected)
  end

end

defmodule Cog.Chat.HipChat.Templates.Embedded.BundleInstallTest do
  use Cog.TemplateCase

  test "bundle-info template" do
    data = %{"results" => [%{"name" => "heroku",
                             "versions" => [%{"version" => "0.0.4"}]}]}

    expected = "Bundle \"heroku\" version \"0.0.4\" installed."

    assert_rendered_template(:hipchat, :embedded, "bundle-install", data, expected)
  end

end

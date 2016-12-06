defmodule Cog.Chat.HipChat.Templates.Embedded.UsageTest do
  use Cog.TemplateCase

  test "usage template - with error" do
    data = %{"results" => [%{"error" => "Oopsie... something went wrong",
                             "usage" => "Do this instead..."}]}
    expected = "<strong>Oopsie... something went wrong</strong><br/><br/><br/>" <>
      "Do this instead..."

    assert_rendered_template(:hipchat, :embedded, "usage", data, expected)
  end

  test "usage template - without error" do
    data = %{"results" => [%{"usage" => "Do this instead..."}]}
    expected = "Do this instead..."

    assert_rendered_template(:hipchat, :embedded, "usage", data, expected)
  end

end

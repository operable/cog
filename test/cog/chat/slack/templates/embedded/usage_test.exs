defmodule Cog.Chat.Slack.Templates.Embedded.UsageTest do
  use Cog.TemplateCase

  test "usage template - with error" do
    data = %{"results" => [%{"error" => "Oopsie... something went wrong",
                             "usage" => "Do this instead..."}]}
    expected = """
    *Oopsie... something went wrong*

    Do this instead...
    """ |> String.strip
    assert_rendered_template(:slack, :embedded, "usage", data, expected)
  end

  test "usage template - without error" do
    data = %{"results" => [%{"usage" => "Do this instead..."}]}
    expected = """
    Do this instead...
    """ |> String.strip
    assert_rendered_template(:slack, :embedded, "usage", data, expected)
  end

end

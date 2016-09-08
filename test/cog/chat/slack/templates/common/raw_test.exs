defmodule Cog.Chat.Slack.Templates.Common.RawTest do
  use Cog.TemplateCase

  test "raw renders properly" do
    data = %{"results" => [%{"foo" => "bar"}]}
    expected = """
    ```[
      {
        "foo": "bar"
      }
    ]```
    """ |> String.strip
    assert_rendered_template(:common, "raw", data, expected)
  end

end

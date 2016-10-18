defmodule Cog.Chat.HipChat.Templates.Embedded.RawTest do
  use Cog.TemplateCase

  test "raw renders properly even when the return contains a body tag" do
    data = %{"results" => [%{"body" => ["bar"]}]}
    expected = "<pre>[\n  {\n    \"body\": [\n      \"bar\"\n    ]\n  }\n]</pre>"
    assert_rendered_template(:hipchat, :embedded, "raw", data, expected)
  end

  test "raw renders properly" do
    data = %{"results" => [%{"foo" => "bar"}]}
    expected = "<pre>[\n  {\n    \"foo\": \"bar\"\n  }\n]</pre>"
    assert_rendered_template(:hipchat, :embedded, "raw", data, expected)
  end

end

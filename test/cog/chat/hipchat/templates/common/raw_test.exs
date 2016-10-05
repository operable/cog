defmodule Cog.Chat.HipChat.Templates.Common.RawTest do
  use Cog.TemplateCase

  test "raw renders properly" do
    data = %{"results" => [%{"foo" => "bar"}]}
    expected = "<pre>[\n  {\n    \"foo\": \"bar\"\n  }\n]</pre>"
    assert_rendered_template(:hipchat, :common, "raw", data, expected)
  end

end

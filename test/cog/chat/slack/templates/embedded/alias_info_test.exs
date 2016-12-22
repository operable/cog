defmodule Cog.Chat.Slack.Templates.Embedded.AliasInfoTest do
  use Cog.TemplateCase

  test "alias-info template" do
    data = %{"results" => [%{"visibility" => "user",
                             "name" => "awesome_alias",
                             "pipeline" => "echo 'awesome!'"}]}
    expected = """
    *Name:* user:awesome_alias
    *Pipeline:* `echo 'awesome!'`
    """ |> String.strip

    assert_rendered_template(:slack, :embedded, "alias-info", data, expected)
  end
end

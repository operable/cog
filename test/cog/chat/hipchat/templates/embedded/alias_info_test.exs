defmodule Cog.Chat.HipChat.Templates.Embedded.AliasInfoTest do
  use Cog.TemplateCase

  test "alias-info template" do
    data = %{"results" => [%{"visibility" => "user",
                             "name" => "awesome_alias",
                             "pipeline" => "echo 'awesome!'"}]}
    expected = """
    <strong>Name:</strong> user:awesome_alias<br/>
    <strong>Pipeline:</strong> <code>echo 'awesome!'</code>
    """ |> String.replace("\n", "")

    assert_rendered_template(:hipchat, :embedded, "alias-info", data, expected)
  end
end

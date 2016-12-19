defmodule Cog.Chat.HipChat.Templates.Embedded.AliasListTest do
  use Cog.TemplateCase

  test "alias-list template" do
    data = %{"results" => [%{"visibility" => "user",
                             "name" => "awesome_alias",
                             "pipeline" => "echo 'awesome!'"},
                           %{"visibility" => "user",
                             "name" => "another_awesome_alias",
                             "pipeline" => "echo 'more awesome!'"},
                           %{"visibility" => "site",
                             "name" => "wow_neat",
                             "pipeline" => "echo 'wow, neat!'"}]}
    expected = """
    <strong>Name:</strong> awesome_alias<br/>
    <strong>Visibility:</strong> user<br/>
    <strong>Pipeline:</strong> <code>echo 'awesome!'</code><br/>
    <br/>
    <strong>Name:</strong> another_awesome_alias<br/>
    <strong>Visibility:</strong> user<br/>
    <strong>Pipeline:</strong> <code>echo 'more awesome!'</code><br/>
    <br/>
    <strong>Name:</strong> wow_neat<br/>
    <strong>Visibility:</strong> site<br/>
    <strong>Pipeline:</strong> <code>echo 'wow, neat!'</code>
    """ |> String.replace("\n", "")

    assert_rendered_template(:hipchat, :embedded, "alias-list", data, expected)
  end

end

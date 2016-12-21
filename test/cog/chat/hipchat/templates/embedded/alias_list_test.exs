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
    user:awesome_alias<br/>
    user:another_awesome_alias<br/>
    site:wow_neat
    """ |> String.replace("\n", "")

    assert_rendered_template(:hipchat, :embedded, "alias-list", data, expected)
  end

end

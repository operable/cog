defmodule Cog.Chat.Slack.Templates.Embedded.AliasListTest do
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
    Found 3 matching aliases.

    Name: ```awesome_alias```
    Visibility: ```user```
    Pipeline: ```echo 'awesome!'```

    Name: ```another_awesome_alias```
    Visibility: ```user```
    Pipeline: ```echo 'more awesome!'```

    Name: ```wow_neat```
    Visibility: ```site```
    Pipeline: ```echo 'wow, neat!'```
    """ |> String.strip

    assert_rendered_template(:slack, :embedded, "alias-list", data, {"", expected})
  end

end

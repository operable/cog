defmodule Cog.Chat.Slack.Templates.Embedded.AliasTest do
  use Cog.TemplateCase

  test "alias-create template" do
    data = %{"results" => [%{"name" => "awesome_alias"}]}
    expected = "Alias 'user:awesome_alias' has been created"
    assert_rendered_template(:embedded, "alias-create", data, expected)
  end

  test "alias-create with multiple inputs" do
    data = %{"results" => [%{"name" => "awesome_alias"},
                           %{"name" => "another_awesome_alias"},
                           %{"name" => "wow_neat"}]}
    expected = """
    Alias 'user:awesome_alias' has been created
    Alias 'user:another_awesome_alias' has been created
    Alias 'user:wow_neat' has been created
    """ |> String.strip

    assert_rendered_template(:embedded, "alias-create", data, expected)
  end

  test "alias-delete template" do
    data = %{"results" => [%{"visibility" => "user", "name" => "awesome_alias"}]}
    expected = "Deleted 'user:awesome_alias'"
    assert_rendered_template(:embedded, "alias-delete", data, expected)
  end

  test "alias-delete with multiple inputs" do
    data = %{"results" => [%{"visibility" => "user", "name" => "awesome_alias"},
                           %{"visibility" => "user", "name" => "another_awesome_alias"},
                           %{"visibility" => "site", "name" => "wow_neat"}]}
    expected = """
    Deleted 'user:awesome_alias'
    Deleted 'user:another_awesome_alias'
    Deleted 'site:wow_neat'
    """ |> String.strip

    assert_rendered_template(:embedded, "alias-delete", data, expected)
  end

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

    assert_rendered_template(:embedded, "alias-list", data, expected)
  end

  test "alias-move template" do
    data = %{"results" => [%{"source" => %{"visibility" => "user",
                                           "name" => "awesome"},
                             "destination" => %{"visibility" => "site",
                                                "name" => "awesome"}}]}
    expected = "Successfully moved user:awesome to site:awesome"
    assert_rendered_template(:embedded, "alias-move", data, expected)
  end

  test "alias-move with multiple inputs" do
    data = %{"results" => [%{"source" => %{"visibility" => "user",
                                           "name" => "awesome"},
                             "destination" => %{"visibility" => "site",
                                                "name" => "awesome"}},
                           %{"source" => %{"visibility" => "user",
                                           "name" => "do_stuff"},
                             "destination" => %{"visibility" => "site",
                                                "name" => "do_stuff"}},
                           %{"source" => %{"visibility" => "user",
                                           "name" => "thingie"},
                             "destination" => %{"visibility" => "site",
                                                "name" => "dohickey"}}]}
    expected = """
    Successfully moved user:awesome to site:awesome
    Successfully moved user:do_stuff to site:do_stuff
    Successfully moved user:thingie to site:dohickey
    """ |> String.strip
    assert_rendered_template(:embedded, "alias-move", data, expected)
  end



end

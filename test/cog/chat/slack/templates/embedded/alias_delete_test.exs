defmodule Cog.Chat.Slack.Templates.Embedded.AliasDeleteTest do
  use Cog.TemplateCase

  test "alias-delete template" do
    data = %{"results" => [%{"visibility" => "user", "name" => "awesome_alias"}]}
    expected = "Deleted alias 'user:awesome_alias'"
    assert_rendered_template(:slack, :embedded, "alias-delete", data, expected)
  end

  test "alias-delete with multiple inputs" do
    data = %{"results" => [%{"visibility" => "user", "name" => "awesome_alias"},
                           %{"visibility" => "user", "name" => "another_awesome_alias"},
                           %{"visibility" => "site", "name" => "wow_neat"}]}

    expected = """
    Deleted alias 'user:awesome_alias'
    Deleted alias 'user:another_awesome_alias'
    Deleted alias 'site:wow_neat'
    """ |> String.strip

    assert_rendered_template(:slack, :embedded, "alias-delete", data, expected)
  end

end

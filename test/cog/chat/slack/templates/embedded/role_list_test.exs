defmodule Cog.Chat.Slack.Templates.Embedded.RoleListTest do
  use Cog.TemplateCase

  test "role-list template" do
    data = %{"results" => [%{"name" => "foo"},
                           %{"name" => "bar"},
                           %{"name" => "baz"}]}

    expected = """
    foo
    bar
    baz
    """ |> String.strip

    assert_rendered_template(:slack, :embedded, "role-list", data, expected)
  end

end

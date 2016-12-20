defmodule Cog.Chat.HipChat.Templates.Embedded.GroupListTest do
  use Cog.TemplateCase

  test "group-list template" do
    data = %{"results" => [%{"name" => "testgroup1"},
                           %{"name" => "testgroup2"},
                           %{"name" => "testgroup3"}]}
    expected = """
    testgroup1<br/>\
    testgroup2<br/>\
    testgroup3
    """ |> String.strip()

    assert_rendered_template(:hipchat, :embedded, "group-list", data, expected)
  end
end

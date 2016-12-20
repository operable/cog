defmodule Cog.Chat.HipChat.Templates.Embedded.GroupDeleteTest do
  use Cog.TemplateCase

  test "group-delete template" do
    data = %{"results" => [%{"name" => "testgroup"}]}
    expected = "Deleted user group 'testgroup'"
    assert_rendered_template(:hipchat, :embedded, "group-delete", data, expected)
  end

  test "group-delete with multiple inputs" do
    data = %{"results" => [%{"name" => "testgroup1"},
                           %{"name" => "testgroup2"},
                           %{"name" => "testgroup3"}]}
    expected = """
    Deleted user group 'testgroup1'<br/>\
    Deleted user group 'testgroup2'<br/>\
    Deleted user group 'testgroup3'
    """ |> String.strip

    assert_rendered_template(:hipchat, :embedded, "group-delete", data, expected)
  end
end

defmodule Cog.Chat.HipChat.Templates.Embedded.RelayGroupListTest do
  use Cog.TemplateCase

  test "relay-group-list template" do
    data = %{"results" => [%{"name" => "foo"},
                           %{"name" => "bar"},
                           %{"name" => "baz"}]}

    expected = """
    foo<br/>
    bar<br/>
    baz
    """ |> String.replace("\n", "")

    assert_rendered_template(:hipchat, :embedded, "relay-group-list", data, expected)
  end

end

defmodule Cog.Chat.HipChat.Templates.Embedded.RelayListTest do
  use Cog.TemplateCase

  test "relay-list template" do
    data = %{"results" => [%{"name" => "relay_one",
                             "status" => "enabled"},
                           %{"name" => "relay_two",
                             "status" => "disabled"},
                           %{"name" => "relay_three",
                             "status" => "enabled"}]}

    expected = """
    relay_one (enabled)<br/>
    relay_two (disabled)<br/>
    relay_three (enabled)
    """ |> String.replace("\n", "")

    assert_rendered_template(:hipchat, :embedded, "relay-list", data, expected)
  end
end

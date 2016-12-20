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
    <strong>Name:</strong> relay_one<br/>
    <strong>Status:</strong> enabled<br/>
    <br/>
    <strong>Name:</strong> relay_two<br/>
    <strong>Status:</strong> disabled<br/>
    <br/>
    <strong>Name:</strong> relay_three<br/>
    <strong>Status:</strong> enabled
    """ |> String.replace("\n", "")

    assert_rendered_template(:hipchat, :embedded, "relay-list", data, expected)
  end
end

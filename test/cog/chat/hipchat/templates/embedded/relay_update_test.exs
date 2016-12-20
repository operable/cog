defmodule Cog.Chat.HipChat.Templates.Embedded.RelayUpdateTest do
  use Cog.TemplateCase

  test "relay-update with one input" do
    data = %{"results" => [%{"name" => "relay_one"}]}
    expected = "Updated relay 'relay_one'"
    assert_rendered_template(:hipchat, :embedded, "relay-update", data, expected)
  end

  test "relay-update template with multiple inupts" do
    data = %{"results" => [%{"name" => "relay_one"},
                           %{"name" => "relay_two"},
                           %{"name" => "relay_three"}]}

    expected = """
    Updated relay 'relay_one'<br/>
    Updated relay 'relay_two'<br/>
    Updated relay 'relay_three'
    """ |> String.replace("\n", "")

    assert_rendered_template(:hipchat, :embedded, "relay-update", data, expected)
  end


end

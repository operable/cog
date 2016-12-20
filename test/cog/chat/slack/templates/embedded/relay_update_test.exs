defmodule Cog.Chat.Slack.Templates.Embedded.RelayUpdateTest do
  use Cog.TemplateCase

  test "relay-update with one input" do
    data = %{"results" => [%{"name" => "relay_one"}]}
    expected = "Updated relay 'relay_one'"
    assert_rendered_template(:slack, :embedded, "relay-update", data, expected)
  end

  test "relay-update template with multiple inupts" do
    data = %{"results" => [%{"name" => "relay_one"},
                           %{"name" => "relay_two"},
                           %{"name" => "relay_three"}]}
    expected = """
    Updated relay 'relay_one'
    Updated relay 'relay_two'
    Updated relay 'relay_three'
    """ |> String.strip

    assert_rendered_template(:slack, :embedded, "relay-update", data, expected)
  end


end

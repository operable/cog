defmodule Cog.Chat.HipChat.Templates.Embedded.RelayUpdateTest do
  use Cog.TemplateCase

  test "relay-update with one input" do
    data = %{"results" => [%{"name" => "relay_one"}]}
    expected = "Relay 'relay_one' has been updated"
    assert_rendered_template(:hipchat, :embedded, "relay-update", data, expected)
  end

  test "relay-update template with multiple inupts" do
    data = %{"results" => [%{"name" => "relay_one"},
                           %{"name" => "relay_two"},
                           %{"name" => "relay_three"}]}
    expected = "Relay 'relay_one' has been updated<br/>" <>
      "Relay 'relay_two' has been updated<br/>" <>
      "Relay 'relay_three' has been updated"

    assert_rendered_template(:hipchat, :embedded, "relay-update", data, expected)
  end


end

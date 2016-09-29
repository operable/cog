defmodule Cog.Chat.HipChat.Templates.Embedded.RelayGroupUpdateSuccessTest do
  use Cog.TemplateCase

  test "relay-group-update-success template with one input" do
    data = %{"results" => [%{"name" => "foo"}]}
    expected = "Relay group 'foo' was successfully updated"
    assert_rendered_template(:hipchat, :embedded, "relay-group-update-success", data, expected)
  end

  test "relay-group-update-success template with multiple inputs" do
    data = %{"results" => [%{"name" => "foo"},
                           %{"name" => "bar"},
                           %{"name" => "baz"}]}
    expected = "Relay group 'foo' was successfully updated<br/>" <>
      "Relay group 'bar' was successfully updated<br/>" <>
      "Relay group 'baz' was successfully updated"

    assert_rendered_template(:hipchat, :embedded, "relay-group-update-success", data, expected)
  end

end

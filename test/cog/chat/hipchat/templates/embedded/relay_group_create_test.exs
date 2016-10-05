defmodule Cog.Chat.HipChat.Templates.Embedded.RelayGroupCreateTest do
  use Cog.TemplateCase

  test "relay-group-create template" do
    data = %{"results" => [%{"name" => "foo"}]}
    expected = "Created relay-group 'foo'"
    assert_rendered_template(:hipchat, :embedded, "relay-group-create", data, expected)
  end

  test "relay-group-create template with multiple inputs" do
    data = %{"results" => [%{"name" => "foo"},
                           %{"name" => "bar"},
                           %{"name" => "baz"}]}
    expected = "Created relay-group 'foo'<br/>" <>
      "Created relay-group 'bar'<br/>" <>
      "Created relay-group 'baz'"

    assert_rendered_template(:hipchat, :embedded, "relay-group-create", data, expected)
  end

end

defmodule Cog.Chat.HipChat.Templates.Embedded.RelayGroupRenameTest do
  use Cog.TemplateCase

  test "relay-group-rename template" do
    data = %{"results" => [%{"old_name" => "foo",
                             "relay_group" => %{"name" => "bar"}}]}
    expected = "Renamed relay group 'foo' to 'bar'"
    assert_rendered_template(:hipchat, :embedded, "relay-group-rename", data, expected)
  end

  test "relay-group-rename template with multiple inputs" do
    data = %{"results" => [%{"old_name" => "foo",
                             "relay_group" => %{"name" => "bar"}},
                           %{"old_name" => "pinky",
                             "relay_group" => %{"name" => "brain"}},
                           %{"old_name" => "mario",
                             "relay_group" => %{"name" => "luigi"}}]}
    expected = "Renamed relay group 'foo' to 'bar'<br/>" <>
      "Renamed relay group 'pinky' to 'brain'<br/>" <>
      "Renamed relay group 'mario' to 'luigi'"

    assert_rendered_template(:hipchat, :embedded, "relay-group-rename", data, expected)
  end

end

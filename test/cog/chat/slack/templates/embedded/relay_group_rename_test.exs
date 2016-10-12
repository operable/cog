defmodule Cog.Chat.Slack.Templates.Embedded.RelayGroupRenameTest do
  use Cog.TemplateCase

  test "relay-group-rename template" do
    data = %{"results" => [%{"old_name" => "foo",
                             "relay_group" => %{"name" => "bar"}}]}
    expected = "Renamed relay group 'foo' to 'bar'"
    assert_rendered_template(:slack, :embedded, "relay-group-rename", data, expected)
  end

  test "relay-group-rename template with multiple inputs" do
    data = %{"results" => [%{"old_name" => "foo",
                             "relay_group" => %{"name" => "bar"}},
                           %{"old_name" => "pinky",
                             "relay_group" => %{"name" => "brain"}},
                           %{"old_name" => "mario",
                             "relay_group" => %{"name" => "luigi"}}]}
    expected = """
    Renamed relay group 'foo' to 'bar'
    Renamed relay group 'pinky' to 'brain'
    Renamed relay group 'mario' to 'luigi'
    """ |> String.strip

    assert_rendered_template(:slack, :embedded, "relay-group-rename", data, expected)
  end

end

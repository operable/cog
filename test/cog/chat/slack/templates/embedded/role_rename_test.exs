defmodule Cog.Chat.Slack.Templates.Embedded.RoleRenameTest do
  use Cog.TemplateCase

  test "role-rename template" do
    data = %{"results" => [%{"old_name" => "foo",
                             "name" => "bar"}]}
    expected = "Renamed role 'foo' to 'bar'"
    assert_rendered_template(:embedded, "role-rename", data, expected)
  end

  test "role-rename template with multiple inputs" do
    data = %{"results" => [%{"old_name" => "foo",
                             "name" => "bar"},
                           %{"old_name" => "pinky",
                             "name" => "brain"},
                           %{"old_name" => "mario",
                             "name" => "luigi"}]}
    expected = """
    Renamed role 'foo' to 'bar'
    Renamed role 'pinky' to 'brain'
    Renamed role 'mario' to 'luigi'
    """ |> String.strip

    assert_rendered_template(:embedded, "role-rename", data, expected)
  end

end

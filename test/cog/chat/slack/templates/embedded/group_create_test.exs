defmodule Cog.Chat.Slack.Templates.Embedded.GroupCreateTest do
  use Cog.TemplateCase

  test "group-create template" do
    data = %{"results" => [%{"roles" => [],
                             "name" => "testgroup",
                             "members" => []}]}
    expected = "Created user group 'testgroup'"
    assert_rendered_template(:slack, :embedded, "group-create", data, expected)
  end

  test "group-create with multiple inputs" do
    data = %{"results" => [%{"roles" => [],
                             "name" => "testgroup1",
                             "members" => []},
                           %{"roles" => [],
                             "name" => "testgroup2",
                             "members" => []},
                           %{"roles" => [],
                             "name" => "testgroup3",
                             "members" => []}]}
    expected = """
    Created user group 'testgroup1'
    Created user group 'testgroup2'
    Created user group 'testgroup3'
    """ |> String.strip

    assert_rendered_template(:slack, :embedded, "group-create", data, expected)
  end

end

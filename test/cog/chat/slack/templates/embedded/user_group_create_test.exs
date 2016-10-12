defmodule Cog.Chat.Slack.Templates.Embedded.UserGroupCreateTest do
  use Cog.TemplateCase

  test "user-group-create template" do
    data = %{"results" => [%{"name" => "foo"}]}
    expected = "Created user group 'foo'"
    assert_rendered_template(:slack, :embedded, "user-group-create", data, expected)
  end

  test "user-group-create template with multiple inputs" do
    data = %{"results" => [%{"name" => "foo"},
                           %{"name" => "bar"},
                           %{"name" => "baz"}]}
    expected = """
    Created user group 'foo'
    Created user group 'bar'
    Created user group 'baz'
    """ |> String.strip

    assert_rendered_template(:slack, :embedded, "user-group-create", data, expected)
  end

end

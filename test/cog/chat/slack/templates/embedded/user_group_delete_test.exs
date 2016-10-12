defmodule Cog.Chat.Slack.Templates.Embedded.UserGroupDeleteTest do
  use Cog.TemplateCase

  test "user-group-delete template" do
    data = %{"results" => [%{"name" => "foo"}]}
    expected = "Deleted user group 'foo'"
    assert_rendered_template(:slack, :embedded, "user-group-delete", data, expected)
  end

  test "user-group-delete template with multiple inputs" do
    data = %{"results" => [%{"name" => "foo"},
                           %{"name" => "bar"},
                           %{"name" => "baz"}]}
    expected = """
    Deleted user group 'foo'
    Deleted user group 'bar'
    Deleted user group 'baz'
    """ |> String.strip

    assert_rendered_template(:slack, :embedded, "user-group-delete", data, expected)
  end

end

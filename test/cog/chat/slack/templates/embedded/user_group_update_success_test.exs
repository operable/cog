defmodule Cog.Chat.Slack.Templates.Embedded.UserGroupUpdateSuccessTest do
  use Cog.TemplateCase

  test "user-group-update-success template" do
    data = %{"results" => [%{"name" => "foo"}]}
    expected = "User group 'foo' was successfully updated"
    assert_rendered_template(:slack, :embedded, "user-group-update-success", data, expected)
  end

  test "user-group-update-success template with multiple inputs" do
    data = %{"results" => [%{"name" => "foo"},
                           %{"name" => "bar"},
                           %{"name" => "baz"}]}
    expected = """
    User group 'foo' was successfully updated
    User group 'bar' was successfully updated
    User group 'baz' was successfully updated
    """ |> String.strip

    assert_rendered_template(:slack, :embedded, "user-group-update-success", data, expected)
  end

end

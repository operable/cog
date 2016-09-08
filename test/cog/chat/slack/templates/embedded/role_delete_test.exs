defmodule Cog.Chat.Slack.Templates.Embedded.RoleDeleteTest do
  use Cog.TemplateCase

  test "role-delete template" do
    data = %{"results" => [%{"name" => "foo"}]}
    expected = "Deleted role 'foo'"
    assert_rendered_template(:embedded, "role-delete", data, expected)
  end

  test "role-delete template with multiple inputs" do
    data = %{"results" => [%{"name" => "foo"},
                           %{"name" => "bar"},
                           %{"name" => "baz"}]}
    expected = """
    Deleted role 'foo'
    Deleted role 'bar'
    Deleted role 'baz'
    """ |> String.strip

    assert_rendered_template(:embedded, "role-delete", data, expected)
  end

end

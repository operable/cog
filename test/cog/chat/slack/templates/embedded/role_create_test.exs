defmodule Cog.Chat.Slack.Templates.Embedded.RoleCreateTest do
  use Cog.TemplateCase

  test "role-create template" do
    data = %{"results" => [%{"name" => "foo"}]}
    expected = "Created role 'foo'"
    assert_rendered_template(:embedded, "role-create", data, expected)
  end

  test "role-create template with multiple inputs" do
    data = %{"results" => [%{"name" => "foo"},
                           %{"name" => "bar"},
                           %{"name" => "baz"}]}
    expected = """
    Created role 'foo'
    Created role 'bar'
    Created role 'baz'
    """ |> String.strip

    assert_rendered_template(:embedded, "role-create", data, expected)
  end

end

defmodule Cog.Chat.Slack.Templates.Embedded.RoleInfoTest do
  use Cog.TemplateCase

  test "role-info template with one input" do
    data = %{"results" => [%{"id" => "123",
                             "name" => "foo",
                             "permissions" => [%{"bundle" => "site", "name" => "foo"}]}]}

    expected = """
    *Name:* foo
    *ID:* 123
    *Permissions:* site:foo
    """ |> String.strip

    assert_rendered_template(:slack, :embedded, "role-info", data, {expected, []})
  end

  test "role-info template with multiple inputs" do
    data = %{"results" => [%{"id" => "123",
                             "name" => "foo",
                             "permissions" => [%{"bundle" => "site", "name" => "foo"}]},
                           %{"id" => "456",
                             "name" => "bar",
                             "permissions" => [%{"bundle" => "site", "name" => "foo"},
                                               %{"bundle" => "operable", "name" => "blah"}]},
                           %{"id" => "789",
                             "name" => "baz",
                             "permissions" => [%{"bundle" => "site", "name" => "foo"}]}]}

    expected = """
    *Name:* foo
    *ID:* 123
    *Permissions:* site:foo
    *Name:* bar
    *ID:* 456
    *Permissions:* site:foo, operable:blah
    *Name:* baz
    *ID:* 789
    *Permissions:* site:foo
    """ |> String.strip

    assert_rendered_template(:slack, :embedded, "role-info", data, expected)
  end

end

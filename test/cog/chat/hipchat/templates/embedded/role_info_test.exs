defmodule Cog.Chat.HipChat.Templates.Embedded.RoleInfoTest do
  use Cog.TemplateCase

  test "role-info template with one input" do
    data = %{"results" => [%{"id" => "123",
                             "name" => "foo",
                             "permissions" => [%{"bundle" => "site", "name" => "foo"}]}]}

    expected = "<strong>ID</strong>: 123<br/>" <>
      "<strong>Name</strong>: foo<br/>" <>
      "<strong>Permissions</strong>: site:foo"

    assert_rendered_template(:hipchat, :embedded, "role-info", data, expected)
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
                             "permissions" => [%{"bundle" => "site", "name" => "foo"}]}

                          ]}

    expected = """
    <pre>+------+-----+-------------------------+
    | Name | ID  | Permissions             |
    +------+-----+-------------------------+
    | foo  | 123 | site:foo                |
    | bar  | 456 | site:foo, operable:blah |
    | baz  | 789 | site:foo                |
    +------+-----+-------------------------+
    </pre>\
    """

    assert_rendered_template(:hipchat, :embedded, "role-info", data, expected)
  end


end

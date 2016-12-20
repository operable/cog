defmodule Cog.Chat.HipChat.Templates.Embedded.RoleInfoTest do
  use Cog.TemplateCase

  test "role-info template with one input" do
    data = %{"results" => [%{"id" => "123",
                             "name" => "foo",
                             "permissions" => [%{"bundle" => "site", "name" => "foo"}]}]}

    expected = """
    <strong>Name:</strong> foo<br/>
    <strong>ID:</strong> 123<br/>
    <strong>Permissions:</strong> site:foo
    """ |> String.replace("\n", "")

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
    <strong>Name:</strong> foo<br/>
    <strong>ID:</strong> 123<br/>
    <strong>Permissions:</strong> site:foo<br/>
    <strong>Name:</strong> bar<br/>
    <strong>ID:</strong> 456<br/>
    <strong>Permissions:</strong> site:foo, operable:blah<br/>
    <strong>Name:</strong> baz<br/>
    <strong>ID:</strong> 789<br/>
    <strong>Permissions:</strong> site:foo
    """ |> String.replace("\n", "")

    assert_rendered_template(:hipchat, :embedded, "role-info", data, expected)
  end


end

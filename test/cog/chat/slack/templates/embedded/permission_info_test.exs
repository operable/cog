defmodule Cog.Chat.Slack.Templates.Embedded.PermissionInfoTest do
  use Cog.TemplateCase

  test "permission-info template" do
    data = %{"results" => [%{"id" => "123", "bundle" => "site", "name" => "foo"}]}

    expected = """
    *ID*: 123
    *Bundle*: site
    *Name*: foo
    """ |> String.strip

    assert_rendered_template(:embedded, "permission-info", data, expected)
  end

  test "permission-info template with multiple inputs" do
    data = %{"results" => [%{"id" => "123", "bundle" => "foo_bundle", "name" => "foo"},
                           %{"id" => "456", "bundle" => "bar_bundle", "name" => "bar"},
                           %{"id" => "789", "bundle" => "baz_bundle", "name" => "baz"}]}

    expected = """
    ```+------------+------+-----+
    | Bundle     | Name | ID  |
    +------------+------+-----+
    | foo_bundle | foo  | 123 |
    | bar_bundle | bar  | 456 |
    | baz_bundle | baz  | 789 |
    +------------+------+-----+
    ```
    """ |> String.strip

    assert_rendered_template(:embedded, "permission-info", data, expected)
  end


end

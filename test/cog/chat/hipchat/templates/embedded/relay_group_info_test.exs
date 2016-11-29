defmodule Cog.Chat.HipChat.Templates.Embedded.RelayGroupInfoTest do
  use Cog.TemplateCase

  test "relay-group-info template with one input" do
    data = %{"results" => [%{"name" => "foo",
                             "created_at" => "some point in the past",
                             "relays" => [%{"name" => "my_relay"},
                                          %{"name" => "my_other_relay"}],
                             "bundles" => [%{"name" => "foo"},
                                           %{"name" => "bar"},
                                           %{"name" => "baz"}]}]}
    expected = "<strong>Name</strong>: foo"

    assert_rendered_template(:hipchat, :embedded, "relay-group-info", data, expected)
  end

  test "relay-group-info template with multiple inputs" do
    data = %{"results" => [%{"name" => "foo",
                             "created_at" => "some point in the past",
                             "relays" => [%{"name" => "my_relay"},
                                          %{"name" => "my_other_relay"}],
                             "bundles" => [%{"name" => "foo"},
                                           %{"name" => "bar"},
                                           %{"name" => "baz"}]},
                           %{"name" => "bar",
                             "created_at" => "long long ago in a galaxy far away",
                             "relays" => [],
                             "bundles" => [%{"name" => "foo"},
                                           %{"name" => "bar"},
                                           %{"name" => "baz"}]},
                           %{"name" => "baz",
                             "created_at" => "right... NOW",
                             "relays" => [%{"name" => "my_relay"},
                                          %{"name" => "my_other_relay"}],
                             "bundles" => []}
                          ]}
    expected = """
    <pre>+------+
    | Name |
    +------+
    | foo  |
    | bar  |
    | baz  |
    +------+
    </pre>\
    """

    assert_rendered_template(:hipchat, :embedded, "relay-group-info", data, expected)
  end

end

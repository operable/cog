defmodule Cog.Chat.HipChat.Templates.Embedded.RelayGroupInfoVerboseTest do
  use Cog.TemplateCase

  test "relay-group-info-verbose template with one input" do
    data = %{"results" => [%{"name" => "foo",
                             "created_at" => "some point in the past",
                             "relays" => [%{"name" => "my_relay"},
                                          %{"name" => "my_other_relay"}],
                             "bundles" => [%{"name" => "foo"},
                                           %{"name" => "bar"},
                                           %{"name" => "baz"}]}]}
    expected = "<strong>Name</strong>: foo<br/>" <>
      "<strong>Created At</strong>: some point in the past<br/>" <>
      "<strong>Relays</strong>: my_relay, my_other_relay<br/>" <>
      "<strong>Bundles</strong>: foo, bar, baz"

    assert_rendered_template(:hipchat, :embedded, "relay-group-info-verbose", data, expected)
  end

  test "relay-group-info-verbose template with multiple inputs" do
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
    <pre>+------+--------------------------+---------------+------------------------------------+
    | Name | Relays                   | Bundles       | Created At                         |
    +------+--------------------------+---------------+------------------------------------+
    | foo  | my_relay, my_other_relay | foo, bar, baz | some point in the past             |
    | bar  |                          | foo, bar, baz | long long ago in a galaxy far away |
    | baz  | my_relay, my_other_relay |               | right... NOW                       |
    +------+--------------------------+---------------+------------------------------------+
    </pre>\
    """

    assert_rendered_template(:hipchat, :embedded, "relay-group-info-verbose", data, expected)
  end

end

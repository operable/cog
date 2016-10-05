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
    <table>
    <th><td>Name</td><td>Relays</td><td>Bundles</td><td>Created At</td></th>
    <tr><td>foo</td><td>my_relay, my_other_relay</td><td>foo, bar, baz</td><td>some point in the past</td></tr>
    <tr><td>bar</td><td></td><td>foo, bar, baz</td><td>long long ago in a galaxy far away</td></tr>
    <tr><td>baz</td><td>my_relay, my_other_relay</td><td></td><td>right... NOW</td></tr>
    </table>
    """

    assert_rendered_template(:hipchat, :embedded, "relay-group-info-verbose", data, expected)
  end

end

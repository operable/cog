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
    expected = """
    <strong>Name:</strong> foo<br/>
    <strong>Relays:</strong> my_relay, my_other_relay<br/>
    <strong>Bundles:</strong> foo, bar, baz
    """ |> String.replace("\n", "")

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
    <strong>Name:</strong> foo<br/>
    <strong>Relays:</strong> my_relay, my_other_relay<br/>
    <strong>Bundles:</strong> foo, bar, baz<br/>
    <br/>
    <strong>Name:</strong> bar<br/>
    <strong>Relays:</strong> No relays<br/>
    <strong>Bundles:</strong> foo, bar, baz<br/>
    <br/>
    <strong>Name:</strong> baz<br/>
    <strong>Relays:</strong> my_relay, my_other_relay<br/>
    <strong>Bundles:</strong> No bundles assigned
    """ |> String.replace("\n", "")

    assert_rendered_template(:hipchat, :embedded, "relay-group-info", data, expected)
  end

end

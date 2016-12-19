defmodule Cog.Chat.HipChat.Templates.Embedded.RelayGroupListTest do
  use Cog.TemplateCase

  test "relay-group-list template" do
    data = %{"results" => [%{"name" => "foo"},
                           %{"name" => "bar"},
                           %{"name" => "baz"}]}

    expected = """
    foo<br/>
    bar<br/>
    baz
    """ |> String.replace("\n", "")

    assert_rendered_template(:hipchat, :embedded, "relay-group-list", data, expected)
  end

  test "relay-group-list verbose template" do
    data = %{"results" => [%{"name" => "foo",
                             "relays" => [%{"name" => "relay1"},
                                          %{"name" => "relay2"}],
                             "bundles" => [%{"name" => "bundle1"},
                                           %{"name" => "bundle2"}]},
                           %{"name" => "bar",
                             "relays" => [%{"name" => "relay1"},
                                          %{"name" => "relay2"}],
                             "bundles" => [%{"name" => "bundle1"},
                                           %{"name" => "bundle2"}]},
                           %{"name" => "baz",
                             "relays" => [%{"name" => "relay1"},
                                          %{"name" => "relay2"}],
                             "bundles" => [%{"name" => "bundle1"},
                                           %{"name" => "bundle2"}]}]}

    expected =
    """
    <strong>Name:</strong> foo<br/>\
    <strong>Relays:</strong> relay1, relay2<br/>\
    <strong>Bundles:</strong> bundle1, bundle2<br/>\
    <br/>\
    <strong>Name:</strong> bar<br/>\
    <strong>Relays:</strong> relay1, relay2<br/>\
    <strong>Bundles:</strong> bundle1, bundle2<br/>\
    <br/>\
    <strong>Name:</strong> baz<br/>\
    <strong>Relays:</strong> relay1, relay2<br/>\
    <strong>Bundles:</strong> bundle1, bundle2
    """ |> String.strip()

    assert_rendered_template(:hipchat, :embedded, "relay-group-list-verbose", data, expected)
  end

end

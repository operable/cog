defmodule Cog.Chat.Slack.Templates.Embedded.RelayGroupListTest do
  use Cog.TemplateCase

  test "relay-group-list template" do
    data = %{"results" => [%{"name" => "foo"},
                           %{"name" => "bar"},
                           %{"name" => "baz"}]}

    expected = """
    foo
    bar
    baz
    """ |> String.strip

    assert_rendered_template(:slack, :embedded, "relay-group-list", data, expected)
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

    attachments = [
    """
    *Name:* foo
    *Relays:* relay1, relay2
    *Bundles:* bundle1, bundle2
    """,
    """
    *Name:* bar
    *Relays:* relay1, relay2
    *Bundles:* bundle1, bundle2
    """,
    """
    *Name:* baz
    *Relays:* relay1, relay2
    *Bundles:* bundle1, bundle2
    """
    ] |> Enum.map(&String.strip/1)

    assert_rendered_template(:slack, :embedded, "relay-group-list-verbose", data, {"", attachments})
  end

end

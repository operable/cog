defmodule Cog.Chat.Slack.Templates.Embedded.RelayInfoTest do
  use Cog.TemplateCase

  test "relay-info template with one item with relay groups" do
    data = %{"results" => [%{"id" => "123",
                             "name" => "relay_one",
                             "status" => "enabled",
                             "relay_groups" => [%{"name" => "prod"},
                                                %{"name" => "preprod"},
                                                %{"name" => "dev"}]}]}
    expected = """
    *Name:* relay_one
    *ID:* 123
    *Status:* enabled
    *Relay Groups:* prod, preprod, dev
    """ |> String.strip

    assert_rendered_template(:slack, :embedded, "relay-info", data, expected)
  end

  test "relay-info template with one item without relay groups" do
    data = %{"results" => [%{"id" => "123",
                             "name" => "relay_one",
                             "status" => "enabled"}]}
    expected = """
    *Name:* relay_one
    *ID:* 123
    *Status:* enabled
    """ |> String.strip

    assert_rendered_template(:slack, :embedded, "relay-info", data, expected)
  end

  test "relay-info with multiple results with relay groups" do
    data = %{"results" => [%{"id" => "123",
                             "name" => "relay_one",
                             "status" => "enabled",
                             "relay_groups" => []},
                           %{"id" => "456",
                             "name" => "relay_two",
                             "status" => "disabled",
                             "relay_groups" => [%{"name" => "prod"},
                                                %{"name" => "preprod"},
                                                %{"name" => "dev"}]},
                           %{"id" => "789",
                             "name" => "relay_three",
                             "status" => "enabled",
                             "relay_groups" => [%{"name" => "prod"}]}]}

    expected = """
    *Name:* relay_one
    *ID:* 123
    *Status:* enabled
    *Relay Groups:* No relay groups
    *Name:* relay_two
    *ID:* 456
    *Status:* disabled
    *Relay Groups:* prod, preprod, dev
    *Name:* relay_three
    *ID:* 789
    *Status:* enabled
    *Relay Groups:* prod
    """ |> String.strip

    assert_rendered_template(:slack, :embedded, "relay-info", data, expected)
  end

  test "relay-info with multiple results without relay groups" do
    data = %{"results" => [%{"id" => "123",
                             "name" => "relay_one",
                             "status" => "enabled"},
                           %{"id" => "456",
                             "name" => "relay_two",
                             "status" => "disabled"},
                           %{"id" => "789",
                             "name" => "relay_three",
                             "status" => "enabled"}]}

    expected = """
    *Name:* relay_one
    *ID:* 123
    *Status:* enabled
    *Name:* relay_two
    *ID:* 456
    *Status:* disabled
    *Name:* relay_three
    *ID:* 789
    *Status:* enabled
    """ |> String.strip

    assert_rendered_template(:slack, :embedded, "relay-info", data, expected)
  end

end

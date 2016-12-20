defmodule Cog.Chat.HipChat.Templates.Embedded.RelayInfoTest do
  use Cog.TemplateCase

  test "relay-info template with one item with relay groups" do
    data = %{"results" => [%{"id" => "123",
                             "name" => "relay_one",
                             "created_at" => "sometime",
                             "status" => "enabled",
                             "relay_groups" => [%{"name" => "prod"},
                                                %{"name" => "preprod"},
                                                %{"name" => "dev"}]}]}


    expected = """
    <strong>Name:</strong> relay_one<br/>
    <strong>ID:</strong> 123<br/>
    <strong>Status:</strong> enabled<br/>
    <strong>Relay Groups:</strong> prod, preprod, dev
    """ |> String.replace("\n", "")

    assert_rendered_template(:hipchat, :embedded, "relay-info", data, expected)
  end

  test "relay-info template with one item without relay groups" do
    data = %{"results" => [%{"id" => "123",
                             "name" => "relay_one",
                             "created_at" => "sometime",
                             "status" => "enabled"}]}

    expected = """
    <strong>Name:</strong> relay_one<br/>
    <strong>ID:</strong> 123<br/>
    <strong>Status:</strong> enabled
    """ |> String.replace("\n", "")

    assert_rendered_template(:hipchat, :embedded, "relay-info", data, expected)
  end

  test "relay-info with multiple results with relay groups" do
    data = %{"results" => [%{"id" => "123",
                             "name" => "relay_one",
                             "created_at" => "yesterday",
                             "status" => "enabled",
                             "relay_groups" => []},
                           %{"id" => "456",
                             "name" => "relay_two",
                             "created_at" => "3 days from now",
                             "status" => "disabled",
                             "relay_groups" => [%{"name" => "prod"},
                                                %{"name" => "preprod"},
                                                %{"name" => "dev"}]},
                           %{"id" => "789",
                             "name" => "relay_three",
                             "created_at" => "the beginning of time itself",
                             "status" => "enabled",
                             "relay_groups" => [%{"name" => "prod"}]}]}


    expected = """
    <strong>Name:</strong> relay_one<br/>
    <strong>ID:</strong> 123<br/>
    <strong>Status:</strong> enabled<br/>
    <strong>Relay Groups:</strong> No relay groups<br/>
    <strong>Name:</strong> relay_two<br/>
    <strong>ID:</strong> 456<br/>
    <strong>Status:</strong> disabled<br/>
    <strong>Relay Groups:</strong> prod, preprod, dev<br/>
    <strong>Name:</strong> relay_three<br/>
    <strong>ID:</strong> 789<br/>
    <strong>Status:</strong> enabled<br/>
    <strong>Relay Groups:</strong> prod
    """ |> String.replace("\n", "")

    assert_rendered_template(:hipchat, :embedded, "relay-info", data, expected)
  end

  test "relay-info with multiple results without relay groups" do
    data = %{"results" => [%{"id" => "123",
                             "name" => "relay_one",
                             "created_at" => "yesterday",
                             "status" => "enabled"},
                           %{"id" => "456",
                             "name" => "relay_two",
                             "created_at" => "3 days from now",
                             "status" => "disabled"},
                           %{"id" => "789",
                             "name" => "relay_three",
                             "created_at" => "the beginning of time itself",
                             "status" => "enabled"}]}

    expected = """
    <strong>Name:</strong> relay_one<br/>
    <strong>ID:</strong> 123<br/>
    <strong>Status:</strong> enabled<br/>
    <br/>
    <strong>Name:</strong> relay_two<br/>
    <strong>ID:</strong> 456<br/>
    <strong>Status:</strong> disabled<br/>
    <br/>
    <strong>Name:</strong> relay_three<br/>
    <strong>ID:</strong> 789<br/>
    <strong>Status:</strong> enabled
    """ |> String.replace("\n", "")

    assert_rendered_template(:hipchat, :embedded, "relay-info", data, expected)
  end

end

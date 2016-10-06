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
    expected = "<strong>ID</strong>: 123<br/>" <>
      "<strong>Created</strong>: sometime<br/>" <>
      "<strong>Name</strong>: relay_one<br/>" <>
      "<strong>Status</strong>: enabled<br/>" <>
      "<strong>Relay Groups</strong>: prod, preprod, dev"

    assert_rendered_template(:hipchat, :embedded, "relay-info", data, expected)
  end

  test "relay-info template with one item without relay groups" do
    data = %{"results" => [%{"id" => "123",
                             "name" => "relay_one",
                             "created_at" => "sometime",
                             "status" => "enabled"}]}
    expected = "<strong>ID</strong>: 123<br/>" <>
      "<strong>Created</strong>: sometime<br/>" <>
      "<strong>Name</strong>: relay_one<br/>" <>
      "<strong>Status</strong>: enabled"

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
    <table>
    <th><td>Name</td><td>Status</td><td>ID</td><td>Created</td><td>Relay Groups</td></th>
    <tr><td>relay_one</td><td>enabled</td><td>123</td><td>yesterday</td><td></td></tr>
    <tr><td>relay_two</td><td>disabled</td><td>456</td><td>3 days from now</td><td>prod, preprod, dev</td></tr>
    <tr><td>relay_three</td><td>enabled</td><td>789</td><td>the beginning of time itself</td><td>prod</td></tr>
    </table>
    """

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
    <table>
    <th><td>Name</td><td>Status</td><td>ID</td><td>Created</td></th>
    <tr><td>relay_one</td><td>enabled</td><td>123</td><td>yesterday</td></tr>
    <tr><td>relay_two</td><td>disabled</td><td>456</td><td>3 days from now</td></tr>
    <tr><td>relay_three</td><td>enabled</td><td>789</td><td>the beginning of time itself</td></tr>
    </table>
    """

    assert_rendered_template(:hipchat, :embedded, "relay-info", data, expected)
  end

end

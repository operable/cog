defmodule Cog.Chat.HipChat.Templates.Embedded.RelayListTest do
  use Cog.TemplateCase

  test "relay-list template with relay groups" do
    data = %{"results" => [%{"name" => "relay_one",
                             "status" => "enabled",
                             "relay_groups" => []},
                           %{"name" => "relay_two",
                             "status" => "disabled",
                             "relay_groups" => [%{"name" => "prod"},
                                                %{"name" => "preprod"},
                                                %{"name" => "dev"}]},
                           %{"name" => "relay_three",
                             "status" => "enabled",
                             "relay_groups" => [%{"name" => "prod"}]}]}

    expected = """
    <table>
    <th><td>Name</td><td>Status</td><td>Relay Groups</td></th>
    <tr><td>relay_one</td><td>enabled</td><td></td></tr>
    <tr><td>relay_two</td><td>disabled</td><td>prod, preprod, dev</td></tr>
    <tr><td>relay_three</td><td>enabled</td><td>prod</td></tr>
    </table>
    """

    assert_rendered_template(:hipchat, :embedded, "relay-list", data, expected)
  end

  test "relay-list template without relay groups" do
    data = %{"results" => [%{"name" => "relay_one",
                             "status" => "enabled"},
                           %{"name" => "relay_two",
                             "status" => "disabled"},
                           %{"name" => "relay_three",
                             "status" => "enabled"}]}

    expected = """
    <table>
    <th><td>Name</td><td>Status</td></th>
    <tr><td>relay_one</td><td>enabled</td></tr>
    <tr><td>relay_two</td><td>disabled</td></tr>
    <tr><td>relay_three</td><td>enabled</td></tr>
    </table>
    """

    assert_rendered_template(:hipchat, :embedded, "relay-list", data, expected)
  end


end

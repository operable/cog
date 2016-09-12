defmodule Cog.Chat.Slack.Templates.Embedded.RelayListTest do
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
    ```+-------------+----------+--------------------+
    | Name        | Status   | Relay Groups       |
    +-------------+----------+--------------------+
    | relay_one   | enabled  |                    |
    | relay_two   | disabled | prod, preprod, dev |
    | relay_three | enabled  | prod               |
    +-------------+----------+--------------------+
    ```
    """ |> String.strip

    assert_rendered_template(:embedded, "relay-list", data, expected)
  end

  test "relay-list template without relay groups" do
    data = %{"results" => [%{"name" => "relay_one",
                             "status" => "enabled"},
                           %{"name" => "relay_two",
                             "status" => "disabled"},
                           %{"name" => "relay_three",
                             "status" => "enabled"}]}

    expected = """
    ```+-------------+----------+
    | Name        | Status   |
    +-------------+----------+
    | relay_one   | enabled  |
    | relay_two   | disabled |
    | relay_three | enabled  |
    +-------------+----------+
    ```
    """ |> String.strip

    assert_rendered_template(:embedded, "relay-list", data, expected)
  end


end

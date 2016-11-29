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
    <pre>+-------------+----------+-----+------------------------------+--------------------+
    | Name        | Status   | ID  | Created                      | Relay Groups       |
    +-------------+----------+-----+------------------------------+--------------------+
    | relay_one   | enabled  | 123 | yesterday                    |                    |
    | relay_two   | disabled | 456 | 3 days from now              | prod, preprod, dev |
    | relay_three | enabled  | 789 | the beginning of time itself | prod               |
    +-------------+----------+-----+------------------------------+--------------------+
    </pre>\
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
    <pre>+-------------+----------+-----+------------------------------+
    | Name        | Status   | ID  | Created                      |
    +-------------+----------+-----+------------------------------+
    | relay_one   | enabled  | 123 | yesterday                    |
    | relay_two   | disabled | 456 | 3 days from now              |
    | relay_three | enabled  | 789 | the beginning of time itself |
    +-------------+----------+-----+------------------------------+
    </pre>\
    """

    assert_rendered_template(:hipchat, :embedded, "relay-info", data, expected)
  end

end

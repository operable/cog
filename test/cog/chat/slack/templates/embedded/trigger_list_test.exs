defmodule Cog.Chat.Slack.Templates.Embedded.TriggerListTest do
  use Cog.TemplateCase

  test "trigger-list template" do
    data = %{"results" => [%{"id" => "abc123",
                             "name" => "test_trigger",
                             "description" => "Tests things!",
                             "enabled" => true,
                             "pipeline" => "echo 'Something just happened'",
                             "as_user" => "bobby_tables",
                             "timeout_sec" => 30,
                             "invocation_url" => "https://cog.mycompany.com/invoke_stuff"},
                          %{"id" => "abc456",
                            "name" => "test_trigger_2",
                            "description" => "Tests more things!",
                            "enabled" => false,
                            "pipeline" => "echo 'Something else just happened'",
                            "as_user" => "bobby_tables",
                            "timeout_sec" => 30,
                            "invocation_url" => "https://cog.mycompany.com/invoke_other_stuff"}]}
    expected = """
    ```+--------+----------------+--------------------+----------+-------------------------------------+--------------+---------+----------------------------------------------+
    | ID     | Name           | Description        | Enabled? | Pipeline                            | As User      | Timeout | Invocation URL                               |
    +--------+----------------+--------------------+----------+-------------------------------------+--------------+---------+----------------------------------------------+
    | abc123 | test_trigger   | Tests things!      | true     | echo 'Something just happened'      | bobby_tables | 30      | https://cog.mycompany.com/invoke_stuff       |
    | abc456 | test_trigger_2 | Tests more things! | false    | echo 'Something else just happened' | bobby_tables | 30      | https://cog.mycompany.com/invoke_other_stuff |
    +--------+----------------+--------------------+----------+-------------------------------------+--------------+---------+----------------------------------------------+
    ```
    """ |> String.strip

    assert_rendered_template(:slack, :embedded, "trigger-list", data, expected)
  end

  test "handles null description, user" do
    data = %{"results" => [%{"id" => "abc123",
                             "name" => "test_trigger",
                             "description" => "Tests things!",
                             "enabled" => true,
                             "pipeline" => "echo 'Something just happened'",
                             "timeout_sec" => 30,
                             "invocation_url" => "https://cog.mycompany.com/invoke_stuff"},
                          %{"id" => "abc456",
                            "name" => "test_trigger_2",
                            "enabled" => false,
                            "pipeline" => "echo 'Something else just happened'",
                            "as_user" => "bobby_tables",
                            "timeout_sec" => 30,
                            "invocation_url" => "https://cog.mycompany.com/invoke_other_stuff"}]}
    expected = """
    ```+--------+----------------+---------------+----------+-------------------------------------+--------------+---------+----------------------------------------------+
    | ID     | Name           | Description   | Enabled? | Pipeline                            | As User      | Timeout | Invocation URL                               |
    +--------+----------------+---------------+----------+-------------------------------------+--------------+---------+----------------------------------------------+
    | abc123 | test_trigger   | Tests things! | true     | echo 'Something just happened'      |              | 30      | https://cog.mycompany.com/invoke_stuff       |
    | abc456 | test_trigger_2 |               | false    | echo 'Something else just happened' | bobby_tables | 30      | https://cog.mycompany.com/invoke_other_stuff |
    +--------+----------------+---------------+----------+-------------------------------------+--------------+---------+----------------------------------------------+
    ```
    """ |> String.strip

    assert_rendered_template(:slack, :embedded, "trigger-list", data, expected)





  end

end

defmodule Cog.Chat.Slack.Templates.Embedded.TriggerInfoTest do
  use Cog.TemplateCase

  test "trigger-info template with one input" do
    data = %{"results" => [%{"id" => "abc123",
                             "name" => "test_trigger",
                             "description" => "Tests things!",
                             "enabled" => true,
                             "pipeline" => "echo 'Something just happened'",
                             "as_user" => "bobby_tables",
                             "timeout_sec" => 30,
                             "invocation_url" => "https://cog.mycompany.com/invoke_stuff"}]}
    expected = """
    *ID*: abc123
    *Name*: test_trigger
    *Description*: Tests things!
    *Enabled?*: true
    *Pipeline*: echo 'Something just happened'
    *As User*: bobby_tables
    *Timeout (sec)*: 30
    *Invocation URL*: https://cog.mycompany.com/invoke_stuff
    """ |> String.strip

    assert_rendered_template(:slack, :embedded, "trigger-info", data, {expected, []})
  end

  test "handles null description, user" do
    data = %{"results" => [%{"id" => "abc123",
                             "name" => "test_trigger",
                             "enabled" => true,
                             "pipeline" => "echo 'Something just happened'",
                             "timeout_sec" => 30,
                             "invocation_url" => "https://cog.mycompany.com/invoke_stuff"}]}
    expected = """
    *ID*: abc123
    *Name*: test_trigger
    *Description*: \n*Enabled?*: true
    *Pipeline*: echo 'Something just happened'
    *As User*: \n*Timeout (sec)*: 30
    *Invocation URL*: https://cog.mycompany.com/invoke_stuff
    """ |> String.strip

    assert_rendered_template(:slack, :embedded, "trigger-info", data, {expected, []})
  end

  test "multiple inputs" do
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

    assert_rendered_template(:slack, :embedded, "trigger-info", data, {"", expected})
  end

end

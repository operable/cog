defmodule Cog.Chat.HipChat.Templates.Embedded.TriggerListTest do
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
    <table>
    <th><td>ID</td><td>Name</td><td>Description</td><td>Enabled?</td><td>Pipeline</td><td>As User</td><td>Timeout</td><td>Invocation URL</td></th>
    <tr><td>abc123</td><td>test_trigger</td><td>Tests things!</td><td>true</td><td>echo 'Something just happened'</td><td>bobby_tables</td><td>30</td><td>https://cog.mycompany.com/invoke_stuff</td></tr>
    <tr><td>abc456</td><td>test_trigger_2</td><td>Tests more things!</td><td>false</td><td>echo 'Something else just happened'</td><td>bobby_tables</td><td>30</td><td>https://cog.mycompany.com/invoke_other_stuff</td></tr>
    </table>
    """

    assert_rendered_template(:hipchat, :embedded, "trigger-list", data, expected)
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
    <table>
    <th><td>ID</td><td>Name</td><td>Description</td><td>Enabled?</td><td>Pipeline</td><td>As User</td><td>Timeout</td><td>Invocation URL</td></th>
    <tr><td>abc123</td><td>test_trigger</td><td>Tests things!</td><td>true</td><td>echo 'Something just happened'</td><td></td><td>30</td><td>https://cog.mycompany.com/invoke_stuff</td></tr>
    <tr><td>abc456</td><td>test_trigger_2</td><td></td><td>false</td><td>echo 'Something else just happened'</td><td>bobby_tables</td><td>30</td><td>https://cog.mycompany.com/invoke_other_stuff</td></tr>
    </table>
    """

    assert_rendered_template(:hipchat, :embedded, "trigger-list", data, expected)

  end

end

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
    *Name:* test_trigger
    *ID:* abc123
    *Description:* Tests things!
    *Status:* Enabled
    *Pipeline:* `echo 'Something just happened'`
    *As User:* bobby_tables
    *Timeout:* 30 seconds
    *Invocation URL:* https://cog.mycompany.com/invoke_stuff
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
    *Name:* test_trigger
    *ID:* abc123
    *Description:* 
    *Status:* Enabled
    *Pipeline:* `echo 'Something just happened'`
    *As User:* 
    *Timeout:* 30 seconds
    *Invocation URL:* https://cog.mycompany.com/invoke_stuff
    """ |> String.strip

    assert_rendered_template(:slack, :embedded, "trigger-info", data, {expected, []})
  end

end

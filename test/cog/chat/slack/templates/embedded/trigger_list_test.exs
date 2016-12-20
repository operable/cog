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
    attachments = [
      """
      *Name:* test_trigger
      *ID:* abc123
      *Enabled:* true
      *Invocation URL:* https://cog.mycompany.com/invoke_stuff
      *Pipeline:* `echo 'Something just happened'`
      """,
      """
      *Name:* test_trigger_2
      *ID:* abc456
      *Enabled:* false
      *Invocation URL:* https://cog.mycompany.com/invoke_other_stuff
      *Pipeline:* `echo 'Something else just happened'`
      """
    ] |> Enum.map(&String.strip/1)

    assert_rendered_template(:slack, :embedded, "trigger-list", data, {"", attachments})
  end
end

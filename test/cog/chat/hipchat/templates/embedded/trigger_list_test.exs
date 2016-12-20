defmodule Cog.Chat.HipChat.Templates.Embedded.TriggerListTest do
  use Cog.TemplateCase

  test "trigger-list template" do
    data = %{"results" => [%{"id" => "abc123",
                             "name" => "test_trigger",
                             "enabled" => true,
                             "pipeline" => "echo 'Something just happened'",
                             "as_user" => "bobby_tables",
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
    <strong>Name:</strong> test_trigger<br/>
    <strong>ID:</strong> abc123<br/>
    <strong>Enabled:</strong> true<br/>
    <strong>Invocation URL:</strong> https://cog.mycompany.com/invoke_stuff<br/>
    <strong>Pipeline:</strong> <code>echo 'Something just happened'</code><br/>
    <br/>
    <strong>Name:</strong> test_trigger_2<br/>
    <strong>ID:</strong> abc456<br/>
    <strong>Enabled:</strong> false<br/>
    <strong>Invocation URL:</strong> https://cog.mycompany.com/invoke_other_stuff<br/>
    <strong>Pipeline:</strong> <code>echo 'Something else just happened'</code>
    """ |> String.replace("\n", "")

    assert_rendered_template(:hipchat, :embedded, "trigger-list", data, expected)
  end
end

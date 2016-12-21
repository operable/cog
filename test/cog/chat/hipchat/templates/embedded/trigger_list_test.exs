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
    test_trigger (enabled)<br/>
    test_trigger_2 (disabled)
    """ |> String.replace("\n", "")

    assert_rendered_template(:hipchat, :embedded, "trigger-list", data, expected)
  end
end

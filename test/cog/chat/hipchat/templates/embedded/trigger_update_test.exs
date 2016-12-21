defmodule Cog.Chat.HipChat.Templates.Embedded.TriggerUpdateTest do
  use Cog.TemplateCase

  test "trigger-update template with one input" do
    data = %{"results" => [%{"id" => "abc123",
                             "name" => "test_trigger",
                             "description" => "Tests things!",
                             "enabled" => true,
                             "pipeline" => "echo 'Something just happened'",
                             "as_user" => "bobby_tables",
                             "timeout_sec" => 30,
                             "invocation_url" => "https://cog.mycompany.com/invoke_stuff"}]}

    expected = "Updated trigger 'test_trigger'"

    assert_rendered_template(:hipchat, :embedded, "trigger-update", data, expected)
  end

  test "handles null description, user" do
    data = %{"results" => [%{"id" => "abc123",
                             "name" => "test_trigger",
                             "enabled" => true,
                             "pipeline" => "echo 'Something just happened'",
                             "timeout_sec" => 30,
                             "invocation_url" => "https://cog.mycompany.com/invoke_stuff"}]}

    expected = "Updated trigger 'test_trigger'"

    assert_rendered_template(:hipchat, :embedded, "trigger-update", data, expected)
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
    Updated trigger 'test_trigger'<br/>
    Updated trigger 'test_trigger_2'
    """ |> String.replace("\n", "")

    assert_rendered_template(:hipchat, :embedded, "trigger-update", data, expected)
  end

end

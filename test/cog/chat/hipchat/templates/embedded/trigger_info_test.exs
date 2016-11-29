defmodule Cog.Chat.HipChat.Templates.Embedded.TriggerInfoTest do
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
    expected = "<strong>ID</strong>: abc123<br/>" <>
      "<strong>Name</strong>: test_trigger<br/>" <>
      "<strong>Description</strong>: Tests things!<br/>" <>
      "<strong>Enabled?</strong>: true<br/>" <>
      "<strong>Pipeline</strong>: echo 'Something just happened'<br/>" <>
      "<strong>As User</strong>: bobby_tables<br/>" <>
      "<strong>Timeout (sec)</strong>: 30<br/>" <>
      "<strong>Invocation URL</strong>: https://cog.mycompany.com/invoke_stuff"


    assert_rendered_template(:hipchat, :embedded, "trigger-info", data, expected)
  end

  test "handles null description, user" do
    data = %{"results" => [%{"id" => "abc123",
                             "name" => "test_trigger",
                             "enabled" => true,
                             "pipeline" => "echo 'Something just happened'",
                             "timeout_sec" => 30,
                             "invocation_url" => "https://cog.mycompany.com/invoke_stuff"}]}
    expected = "<strong>ID</strong>: abc123<br/>" <>
      "<strong>Name</strong>: test_trigger<br/>" <>
      "<strong>Description</strong>: <br/>" <>
      "<strong>Enabled?</strong>: true<br/>" <>
      "<strong>Pipeline</strong>: echo 'Something just happened'<br/>" <>
      "<strong>As User</strong>: <br/>" <>
      "<strong>Timeout (sec)</strong>: 30<br/>" <>
      "<strong>Invocation URL</strong>: https://cog.mycompany.com/invoke_stuff"

    assert_rendered_template(:hipchat, :embedded, "trigger-info", data, expected)
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
    <pre>+--------+----------------+---------------+----------+-------------------------------------+--------------+---------+----------------------------------------------+
    | ID     | Name           | Description   | Enabled? | Pipeline                            | As User      | Timeout | Invocation URL                               |
    +--------+----------------+---------------+----------+-------------------------------------+--------------+---------+----------------------------------------------+
    | abc123 | test_trigger   | Tests things! | true     | echo 'Something just happened'      |              | 30      | https://cog.mycompany.com/invoke_stuff       |
    | abc456 | test_trigger_2 |               | false    | echo 'Something else just happened' | bobby_tables | 30      | https://cog.mycompany.com/invoke_other_stuff |
    +--------+----------------+---------------+----------+-------------------------------------+--------------+---------+----------------------------------------------+
    </pre>\
    """

    assert_rendered_template(:hipchat, :embedded, "trigger-info", data, expected)
  end

end

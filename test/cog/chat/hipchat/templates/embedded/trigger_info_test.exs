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
    expected = "<strong>Name:</strong> test_trigger<br/>" <>
      "<strong>ID:</strong> abc123<br/>" <>
      "<strong>Description:</strong> Tests things!<br/>" <>
      "<strong>Status:</strong> Enabled<br/>" <>
      "<strong>Pipeline:</strong> <code>echo 'Something just happened'</code><br/>" <>
      "<strong>As User:</strong> bobby_tables<br/>" <>
      "<strong>Timeout:</strong> 30 seconds<br/>" <>
      "<strong>Invocation URL:</strong> https://cog.mycompany.com/invoke_stuff"


    assert_rendered_template(:hipchat, :embedded, "trigger-info", data, expected)
  end

  test "handles null description, user" do
    data = %{"results" => [%{"id" => "abc123",
                             "name" => "test_trigger",
                             "enabled" => true,
                             "pipeline" => "echo 'Something just happened'",
                             "timeout_sec" => 30,
                             "invocation_url" => "https://cog.mycompany.com/invoke_stuff"}]}
    expected = "<strong>Name:</strong> test_trigger<br/>" <>
      "<strong>ID:</strong> abc123<br/>" <>
      "<strong>Description:</strong> <br/>" <>
      "<strong>Status:</strong> Enabled<br/>" <>
      "<strong>Pipeline:</strong> <code>echo 'Something just happened'</code><br/>" <>
      "<strong>As User:</strong> <br/>" <>
      "<strong>Timeout:</strong> 30 seconds<br/>" <>
      "<strong>Invocation URL:</strong> https://cog.mycompany.com/invoke_stuff"

    assert_rendered_template(:hipchat, :embedded, "trigger-info", data, expected)
  end

end

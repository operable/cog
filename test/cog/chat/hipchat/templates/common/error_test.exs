defmodule Cog.Chat.HipChat.Templates.Common.ErrorTest do
  use Cog.TemplateCase

  test "error template; planning failure" do
    data = %{"id" => "deadbeef",
             "started" => "some time in the past",
             "initiator" => "somebody",
             "pipeline_text" => "echo foo",
             "error_message" => "bad stuff happened",
             "planning_failure" => "I can't plan this!",
             "execution_failure" => ""}

    directives = directives_for_template(:common, "error", data)
    rendered = Cog.Chat.HipChat.TemplateProcessor.render(directives)
    expected =
      "<strong>Pipeline Error</strong><br/>" <>
      "<pre>bad stuff happened</pre><br/>" <>
      "<strong>Started:</strong><br/>" <>
      "some time in the past<br/>" <>
      "<br/>" <>
      "<strong>Pipeline ID:</strong><br/>" <>
      "deadbeef<br/>" <>
      "<br/>" <>
      "<strong>Pipeline:</strong><br/>" <>
      "echo foo<br/>" <>
      "<br/>" <>
      "<strong>Failed Planning:</strong><br/>" <>
      "I can't plan this!<br/>" <>
      "<br/>" <>
      "<strong>Caller:</strong><br/>" <>
      "somebody<br/>"

    assert expected == rendered
  end

  test "error template; execution failure" do

    data = %{"id" => "deadbeef",
             "started" => "some time in the past",
             "initiator" => "somebody",
             "pipeline_text" => "echo foo",
             "error_message" => "bad stuff happened",
             "planning_failure" => "",
             "execution_failure" => "I can't execute this!"}
    directives = directives_for_template(:common, "error", data)
    rendered = Cog.Chat.HipChat.TemplateProcessor.render(directives)
    expected =
      "<strong>Command Execution Error</strong><br/>" <>
      "<pre>bad stuff happened</pre><br/>" <>
      "<strong>Started:</strong><br/>" <>
      "some time in the past<br/>" <>
      "<br/>" <>
      "<strong>Pipeline ID:</strong><br/>" <>
      "deadbeef<br/>" <>
      "<br/>" <>
      "<strong>Pipeline:</strong><br/>" <>
      "echo foo<br/>" <>
      "<br/>" <>
      "<strong>Failed Executing:</strong><br/>" <>
      "I can't execute this!<br/>" <>
      "<br/>" <>
      "<strong>Caller:</strong><br/>" <>
      "somebody<br/>"

      assert expected == rendered
  end

end

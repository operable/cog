defmodule Cog.Chat.HipChat.Templates.Common.ErrorTest do
  use Cog.TemplateCase

  test "error template; planning failure" do
    data = %{"id" => "deadbeef",
             "started" => "some time in the past",
             "initiator" => "somebody",
             "pipeline_text" => "echo foo",
             "error_message" => "bad stuff happened",
             "planning_failure" => "I can't plan this!",
             "execution_failure" => false}

    directives = directives_for_template(:common, "error", data)
    rendered = Cog.Chat.HipChat.TemplateProcessor.render(directives)
    assert "<strong>Command Error</strong><br/><br/>" <>
      "<strong>Started:</strong> some time in the past<br/>" <>
      "<strong>Pipeline ID:</strong> deadbeef<br/>" <>
      "<strong>Pipeline:</strong> echo foo<br/>" <>
      "<strong>Caller:</strong> somebody<br/><br/>" <>
      "The pipeline failed planning the invocation:<br/><br/>" <>
      "<pre>I can't plan this!</pre><br/><br/>" <>
      "The specific error was:<br/><br/><pre>bad stuff happened</pre>" == rendered
  end

  test "error template; execution failure" do

    data = %{"id" => "deadbeef",
             "started" => "some time in the past",
             "initiator" => "somebody",
             "pipeline_text" => "echo foo",
             "error_message" => "bad stuff happened",
             "planning_failure" => false,
             "execution_failure" => "I can't execute this!"}
    directives = directives_for_template(:common, "error", data)
    rendered = Cog.Chat.HipChat.TemplateProcessor.render(directives)
    assert "<strong>Command Error</strong><br/><br/>" <>
      "<strong>Started:</strong> some time in the past<br/>" <>
      "<strong>Pipeline ID:</strong> deadbeef<br/>" <>
      "<strong>Pipeline:</strong> echo foo<br/>" <>
      "<strong>Caller:</strong> somebody<br/><br/>" <>
      "The pipeline failed executing the command:<br/><br/>" <>
      "<pre>I can't execute this!</pre><br/><br/>" <>
      "The specific error was:<br/><br/><pre>bad stuff happened</pre>" == rendered
  end

end

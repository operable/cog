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

    assert "<strong>Pipeline Error</strong><br/>" <>
      "The pipeline failed planning the invocation:<br/>" <>
      "<pre>I can't plan this!</pre><br/>" <>
      "<strong>Error Message</strong><br/>" <>
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
      "<strong>Caller:</strong><br/>" <>
      "somebody<br/><br/><br/>" == rendered
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

    assert "<strong>Command Error</strong><br/>" <>
      "The pipeline failed executing the command:<br/>" <>
      "<pre>I can't execute this!</pre><br/>" <>
      "<strong>Error Message</strong><br/>" <>
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
      "<strong>Caller:</strong><br/>" <>
      "somebody<br/>" <>
      "<br/>" <>
      "<br/>" == rendered
  end

end

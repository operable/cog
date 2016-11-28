defmodule Cog.Chat.Slack.Templates.Common.ErrorTest do
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
    {"", rendered} = Cog.Chat.Slack.TemplateProcessor.render(directives)

    expected = [
      "The pipeline failed planning the invocation:\n```I can't plan this!```",
      "```bad stuff happened```",
      ""
    ]

    expected
    |> Enum.with_index
    |> Enum.each(
         fn({text, idx}) ->
           assert text == Enum.at(rendered, idx) |> Map.get("text")
         end)
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
    {"", rendered} = Cog.Chat.Slack.TemplateProcessor.render(directives)


    expected = [
      "The pipeline failed executing the command:\n```I can't execute this!```",
      "```bad stuff happened```",
      ""
    ]

    expected
    |> Enum.with_index
    |> Enum.each(
         fn({text, idx}) ->
           assert text == Enum.at(rendered, idx) |> Map.get("text")
         end)
  end

end

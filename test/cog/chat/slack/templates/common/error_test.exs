defmodule Cog.Chat.Slack.Templates.Common.ErrorTest do
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
    {"", [rendered]} = Greenbar.Renderers.SlackRenderer.render(directives)

    expected = "```bad stuff happened```"
    assert ^expected = Map.get(rendered, "text")
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
    {"", [rendered]} = Greenbar.Renderers.SlackRenderer.render(directives)

    expected = "```bad stuff happened```"
    assert ^expected = Map.get(rendered, "text")
  end

end

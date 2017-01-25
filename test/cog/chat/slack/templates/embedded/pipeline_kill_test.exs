defmodule Cog.Chat.Slack.Templates.Embedded.PipelineKillTest do

  use Cog.TemplateCase

  test "pipeline-kill template" do

    data = %{"results" => [
              %{"killed_text" => "echo 'Dead, Jim!'"}
            ]}

    expected = "Pipelines killed: echo 'Dead, Jim!'"

    assert_rendered_template(:slack, :embedded, "pipeline-kill", data, expected)
  end
end

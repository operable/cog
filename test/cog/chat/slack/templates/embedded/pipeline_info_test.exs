defmodule Cog.Chat.Slack.Templates.Embedded.PipelineInfoTest do

  use Cog.TemplateCase

  test "pipeline-info template" do

    data = %{"results" => [
              %{"id" => "beefbeefbeefbeef",
                "text" => "echo foo",
                "time" => "123",
                "user" => "chris",
                "room" => "dev",
                "state" => "running",
                "started" => "Noon",
                "processed" => "1"
               }
            ]}

    attachments = [
    """
    *Id:* beefbeefbeefbeef
    *Text:* `echo foo`
    *Time:* 123 ms
    *User:* chris
    *Room:* dev
    *State:* running
    *Started:* Noon
    *Processed:* 1
    """ |> String.strip
    ]

    assert_rendered_template(:slack, :embedded, "pipeline-info", data, {"", attachments})
  end
end

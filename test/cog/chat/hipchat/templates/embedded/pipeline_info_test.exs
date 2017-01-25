defmodule Cog.Chat.Hipchat.Templates.Embedded.PipelineInfoTest do

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
                "processed" => 1
               }
            ]}

    expected = """
    <strong>Id:</strong> beefbeefbeefbeef<br/>
    <strong>Text:</strong> <code>echo foo</code><br/>
    <strong>Time:</strong> 123 ms<br/>
    <strong>User:</strong> chris<br/>
    <strong>Room:</strong> dev<br/>
    <strong>State:</strong> running<br/>
    <strong>Started:</strong> Noon<br/>
    <strong>Processed:</strong> 1
    """ |> String.replace("\n", "")

    assert_rendered_template(:hipchat, :embedded, "pipeline-info", data, expected)
  end
end

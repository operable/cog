defmodule Cog.Chat.Slack.Templates.Embedded.PipelineListTest do

  use Cog.TemplateCase

  test "pipeline-list template with no pipelines" do

    data = %{"results" => [
              %{"pipeline_count" => 0}
            ]}

    expected = "No pipelines found."

    assert_rendered_template(:slack, :embedded, "pipeline-list", data, expected)
  end

  test "pipeline-list template with pipelines" do
    data = %{"results" => [
              %{"pipeline_count" => 2,
                "pipelines" => [
                  %{"id" => "beefbeefbeefbeef",
                    "text" => "echo foo",
                    "time" => "123",
                    "user" => "chris",
                    "room" => "dev",
                    "state" => "running",
                    "started" => "Noon",
                    "processed" => "1"},
                  %{"id" => "beefbeefbeefbeef",
                    "text" => "echo foo",
                    "time" => "123",
                    "user" => "chris",
                    "room" => "dev",
                    "state" => "running",
                    "started" => "Noon",
                    "processed" => "1"}]}]}

    expected = """
    ```+------------------+----------+-------+------+---------+-----------+---------+------+
    | Id               | Text     | User  | Room | State   | Processed | Started | Time |
    +------------------+----------+-------+------+---------+-----------+---------+------+
    | beefbeefbeefbeef | echo foo | chris | dev  | running | 1         | Noon    | 123  |
    | beefbeefbeefbeef | echo foo | chris | dev  | running | 1         | Noon    | 123  |
    +------------------+----------+-------+------+---------+-----------+---------+------+
    ```
    """ |> String.strip

    assert_rendered_template(:slack, :embedded, "pipeline-list", data, expected)
  end
end

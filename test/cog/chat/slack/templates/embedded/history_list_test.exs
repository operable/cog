defmodule Cog.Chat.Slack.Templates.Embedded.HistoryListTest do

  use Cog.TemplateCase

  test "history-list template" do

    data = %{"results" => [
              %{"index" => 1,
                "text" => "echo foo"},
              %{"index" => 2,
                "text" => "echo bar"}
            ]}

    expected = """
    ```+-------+----------+
    | Index | Pipeline |
    +-------+----------+
    | 1     | echo foo |
    | 2     | echo bar |
    +-------+----------+
    ```
    """ |> String.strip()

    assert_rendered_template(:slack, :embedded, "history-list", data, expected)
  end
end

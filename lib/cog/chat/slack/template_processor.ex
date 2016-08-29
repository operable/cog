defmodule Cog.Chat.Slack.TemplateProcessor do

  # TODO: Escape HTML-encode &, <, and >
  # (see https://api.slack.com/docs/message-formatting#how_to_escape_characters)
  #
  # TODO: Handle errors (e.g. unrecognized directives, table-rendering
  # issues) in a sane way

  def render(directives) do
    directives
    |> Enum.map(&process_directive/1)
    |> Enum.join
  end

  defp process_directive(%{"name" =>  "text", "text" => text}),
    do: text
  defp process_directive(%{"name" =>  "italic", "text" => text}),
    do: "_#{text}_"
  defp process_directive(%{"name" =>  "bold", "text" => text}),
    do: "*#{text}*"
  defp process_directive(%{"name" =>  "fixed_width", "text" => text}),
    do: "```#{text}```"
  defp process_directive(%{"name" =>  "table", "columns" => columns, "rows" => rows}),
    do: "```#{TableRex.quick_render!(rows, columns)}```"
  defp process_directive(%{"name" =>  "newline"}),
    do: "\n"

end

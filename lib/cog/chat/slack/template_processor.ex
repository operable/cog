defmodule Cog.Chat.Slack.TemplateProcessor do
  require Logger

  def render(directives),
    do: Enum.map_join(directives, &process_directive/1)

  ########################################################################

  defp process_directive(%{"name" => "text", "text" => text}),
    do: text
  defp process_directive(%{"name" => "italic", "text" => text}),
    do: "_#{text}_"
  defp process_directive(%{"name" => "bold", "text" => text}),
    do: "*#{text}*"
  defp process_directive(%{"name" => "fixed_width", "text" => text}),
    do: "```#{text}```"
  defp process_directive(%{"name" => "table", "columns" => columns, "rows" => rows}),
    do: "```#{TableRex.quick_render!(rows, columns)}```"
  defp process_directive(%{"name" => "newline"}),
    do: "\n"
  defp process_directive(%{"text" => text}=directive) do
    Logger.warn("Unrecognized directive; formatting as plain text: #{inspect directive}")
    text
  end
  defp process_directive(%{"name" => name}=directive) do
    Logger.warn("Unrecognized directive; #{inspect directive}")
    "\nUnrecognized directive: #{name}\n"
  end

end

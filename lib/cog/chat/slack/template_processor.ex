defmodule Cog.Chat.Slack.TemplateProcessor do
  require Logger

  def render(directives),
    do: Enum.map_join(directives, &process_directive/1)

  ########################################################################

  # Directive processing can sometimes require contextual information
  # in order to properly render (e.g., keeping track of which element
  # of an ordered list you're processing, for instance). In these
  # cases, we'll use a keyword list to capture the context. Not all
  # directives require this, however; thus, we provide a default
  # implementation with an empty context.
  defp process_directive(directive),
    do: process_directive(directive, [])

  defp process_directive(%{"name" => "text", "text" => text}, _),
    do: text
  defp process_directive(%{"name" => "italic", "text" => text}, _),
    do: "_#{text}_"
  defp process_directive(%{"name" => "bold", "text" => text}, _),
    do: "*#{text}*"
  defp process_directive(%{"name" => "fixed_width", "text" => text}, _),
    do: "```#{text}```"
  defp process_directive(%{"name" => "table", "columns" => columns, "rows" => rows}, _),
    do: "```#{TableRex.quick_render!(rows, columns)}```"
  defp process_directive(%{"name" => "newline"}, _),
    do: "\n"
  defp process_directive(%{"name" => "unordered_list", "children" => children}, _),
    do: Enum.map_join(children, &process_directive(&1, bullet: "*"))
  defp process_directive(%{"name" => "ordered_list", "children" => children}, _) do
    {lines, _} = Enum.map_reduce(children, 1, fn(child, counter) ->
      line = process_directive(child, bullet: "#{counter}.")
      {line, counter + 1}
    end)
    lines
  end
  defp process_directive(%{"name" => "list_item", "children" => children}, bullet: bullet),
    do: "#{bullet} #{Enum.map_join(children, &process_directive/1)}"
  defp process_directive(%{"text" => text}=directive, _) do
    Logger.warn("Unrecognized directive; formatting as plain text: #{inspect directive}")
    text
  end
  defp process_directive(%{"name" => name}=directive, _) do
    Logger.warn("Unrecognized directive; #{inspect directive}")
    "\nUnrecognized directive: #{name}\n"
  end

end

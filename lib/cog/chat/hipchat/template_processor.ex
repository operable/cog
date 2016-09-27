defmodule Cog.Chat.HipChat.TemplateProcessor do
  require Logger

  def render(directives) do
    render_directives(directives)
  end

  defp process_directive(%{"name" => "attachment", "children" => children}) do
    Logger.warn("Rendering attachment contents only")
    render(children)
  end
  defp process_directive(%{"name" => "text", "text" => text}),
    do: text
  defp process_directive(%{"name" => "italics", "text" => text}),
    do: "<i>#{text}</i>"
  defp process_directive(%{"name" => "bold", "text" => text}),
    do: "<strong>#{text}</strong>"
  defp process_directive(%{"name" => "fixed_width", "text" => text}),
    do: "<pre>#{text}</pre>"

  defp process_directive(%{"name" => "newline"}), do: "<br/>"

  defp process_directive(%{"name" => "unordered_list", "children" => children}) do
    items = Enum.map_join(children, &process_directive/1)
    "<ul>#{items}</ul>"
  end

  defp process_directive(%{"name" => "ordered_list", "children" => children}) do
    items = Enum.map_join(children, &process_directive/1)
    "<ol>#{items}</ol>"
  end

  defp process_directive(%{"name" => "list_item", "children" => children}) do
    item = Enum.map_join(children, &process_directive/1)
    "<li>#{item}</li>"
  end

  defp process_directive(%{"name" => "table", "children" => children}) do
    "<table>\n#{render(children)}</table>\n"
  end

  defp process_directive(%{"name" => "table_header", "children" => children}) do
    "<th>#{render(children)}</th>\n"
  end

  defp process_directive(%{"name" => "table_row", "children" => children}) do
    "<tr>#{render(children)}</tr>\n"
  end

  defp process_directive(%{"name" => "table_cell", "children" => children}) do
    "<td>#{render(children)}</td>"
  end

  defp process_directive(%{"text" => text}=directive) do
    Logger.warn("Unrecognized directive; formatting as plain text: #{inspect directive}")
    text
  end
  defp process_directive(%{"name" => name}=directive) do
    Logger.warn("Unrecognized directive; #{inspect directive}")
    "\nUnrecognized directive: #{name}\n"
  end

  defp render_directives(directives) do
    directives
    |> Enum.map_join(&process_directive/1) # Convert all Greenbar directives into their HipChat forms
  end

end

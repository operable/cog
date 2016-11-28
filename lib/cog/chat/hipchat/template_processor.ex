defmodule Cog.Chat.HipChat.TemplateProcessor do
  require Logger

  @attachment_fields ["footer", "fields", "children", "pretext", "author", "title"]

  def render(directives) do
    render_directives(directives)
  end

  defp process_directive(%{"name" => "attachment"}=attachment) do
    rendered_body = @attachment_fields
    |> Enum.reduce([], &(render_attachment(&1, &2, attachment)))
    |> List.flatten
    |> Enum.join
    rendered_body <> "<br/>"
  end
  defp process_directive(%{"name" => "text", "text" => text}),
    do: text
  defp process_directive(%{"name" => "italics", "text" => text}),
    do: "<i>#{text}</i>"
  defp process_directive(%{"name" => "bold", "text" => text}),
    do: "<strong>#{text}</strong>"
  defp process_directive(%{"name" => "fixed_width", "text" => text}),
    do: "<code>#{text}</code>"
  defp process_directive(%{"name" => "fixed_width_block", "text" => text}),
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
    children = case List.last(children) do
                 %{"name" => "newline"} ->
                   List.delete_at(children, -1)
                 _  ->
                   children
               end
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
    "<br/>Unrecognized directive: #{name}<br/>"
  end

  defp render_directives(directives) do
    directives
    |> Enum.map_join(&process_directive/1) # Convert all Greenbar directives into their HipChat forms
  end

  defp render_attachment("footer", acc, attachment) do
    case Map.get(attachment, "footer") do
      nil ->
        acc
      footer ->
        ["<br/>#{footer}"|acc]
    end
  end
  defp render_attachment("children", acc, attachment) do
    case Map.get(attachment, "children") do
      nil ->
        acc
      children ->
        [render(children) <> "<br/>"|acc]
    end
  end
  defp render_attachment("fields", acc, attachment) do
    case Map.get(attachment, "fields") do
      nil ->
        acc
      fields ->
        rendered_fields = fields
        |> Enum.map(fn(%{"title" => title, "value" => value}) -> "<strong>#{title}:</strong><br/>#{value}<br/><br/>" end)
        |> Enum.join
        [rendered_fields|acc]
    end
  end
  defp render_attachment("pretext", acc, attachment) do
    case Map.get(attachment, "pretext") do
      nil ->
        acc
      pretext ->
        ["#{pretext}<br/>"|acc]
    end
  end
  defp render_attachment("author", acc, attachment) do
    case Map.get(attachment, "author") do
      nil ->
        acc
      author ->
        ["<strong>Author:</strong> #{author}<br/>"|acc]
    end
  end
  defp render_attachment("title", acc, attachment) do
    case Map.get(attachment, "title") do
      nil ->
        acc
      title ->
        case Map.get(attachment, "title_url") do
          nil ->
            ["<strong>#{title}</strong><br/>"|acc]
          url ->
            ["<strong><a href=\"#{url}\">title</a></strong><br/>"|acc]
        end
    end
  end

end

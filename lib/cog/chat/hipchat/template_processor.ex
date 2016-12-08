defmodule Cog.Chat.HipChat.TemplateProcessor do
  require Logger

  @attachment_fields ["footer", "fields", "children", "pretext", "author", "title"]

  def render(directives) do
    render_directives(directives)
  end

  defp render_directives(directives) do
    directives
    |> Enum.map_join(&process_directive/1) # Convert all Greenbar directives into their HipChat forms
    |> reduce_block_padding                # Remove extra padding above li, ul, pre
    |> String.replace(~r/(<br\/>)+\z/, "")
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
  defp process_directive(%{"name" => "paragraph", "children" => children}),
    do: Enum.map_join(children, &process_directive/1) <> "<br/><br/>"
  # If you try to render a link with nil or blank text, HipChat displays nothing to the user.
  # This way at least a link is rendered. This basically mirrors the default Slack behavior.
  defp process_directive(%{"name" => "link", "text" => text, "url" => url}) when text in [nil, ""],
    do: "<a href='#{url}'>#{url}</a>"
  # Rendering a link in HipChat with a nil or blank url will obviously result in an invalid link. We
  # inform the user inline that there was a problem and log a warning.
  defp process_directive(%{"name" => "link", "text" => text, "url" => url}=directive) when url in [nil, ""] do
    Logger.warn("Invalid link; #{inspect directive}")
    ~s[(invalid link! text:"#{text}" url: "#{url}")]
  end
  defp process_directive(%{"name" => "link", "text" => text, "url" => url}),
    do: "<a href='#{url}'>#{text}</a>"

  defp process_directive(%{"name" => "newline"}), do: "<br/>"

  defp process_directive(%{"name" => "unordered_list", "children" => children}) do
    items = Enum.map_join(children, &process_directive/1)
    "<ul>#{items}</ul><br/>"
  end

  defp process_directive(%{"name" => "ordered_list", "children" => children}) do
    items = Enum.map_join(children, &process_directive/1)
    "<ol>#{items}</ol><br/>"
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

  # Render table as text using TableRex instead of the HTML tags. The HipChat
  # native table experience is very lacking in terms of style options. So much
  # so that text tables are preferable. Note, tables MUST have a header.

  defp process_directive(%{"name" => "table",
                           "children" => [%{"name" => "table_header",
                                            "children" => header}|rows]}) do
    headers = map(header)

    case map(rows) do
      [] ->
        # TableRex doesn't currently like tables without
        # rows for some reason... so we get to render an
        # empty table ourselves :/
        "<pre>#{render_empty_table(headers)}</pre>"
      rows ->
        "<pre>#{TableRex.quick_render!(rows, headers)}</pre>"
    end
  end
  defp process_directive(%{"name" => "table_row", "children" => children}),
    do: map(children)
  defp process_directive(%{"name" => "table_cell", "children" => children}),
    do: Enum.map_join(children, &process_directive/1)

  defp process_directive(%{"text" => text}=directive) do
    Logger.warn("Unrecognized directive; formatting as plain text: #{inspect directive}")
    text
  end
  defp process_directive(%{"name" => name}=directive) do
    Logger.warn("Unrecognized directive; #{inspect directive}")
    "<br/>Unrecognized directive: #{name}<br/>"
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

  # Shortcut for processing a list of directives without additional
  # context, since it's so common
  defp map(directives),
    do: Enum.map(directives, &process_directive/1)

  # This replicates the default TableRex style we use above
  #
  # Example:
  #
  #    +--------+------+
  #    | Bundle | Name |
  #    +--------+------+
  #
  defp render_empty_table(headers) do
    separator_row = "+-#{Enum.map_join(headers, "-+-", &to_hyphens/1)}-+"

    """
    #{separator_row}
    | #{Enum.join(headers, " | ")} |
    #{separator_row}
    """ |> String.strip
  end

  defp to_hyphens(name),
    do: String.duplicate("-", String.length(name))

  defp reduce_block_padding(string) do
    String.replace(string, ~r{<br/>(<ul>|<ol>|<pre>)}, "\\1")
  end
end

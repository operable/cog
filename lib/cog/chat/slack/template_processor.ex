defmodule Cog.Chat.Slack.TemplateProcessor do
  require Logger

  alias Cog.Util.Colors

  @markdown_fields ["author", "text", "title", "pretext"]
  @too_long_for_message 256

  def render(directives) do
    render_directives(directives)
  end

  defp render_directives(directives) do
    {text, attachments} = directives
                          |> Enum.map(&process_directive/1) # Convert all Greenbar directives into their Slack forms
                          |> List.flatten                   # Flatten nested lists into a single list
                          |> consolidate_outputs({"", []})  # Separate message text and attachments into separate lists
    attachments = Enum.map(attachments, &finalize_attachment/1) # Final attachment post-processing for Slack
    text = String.replace(text, ~r/\n$/, "")
    {text, Enum.reverse(attachments)}
  end


  ########################################################################

  # Directive processing can sometimes require contextual information
  # in order to properly render (e.g., keeping track of which element
  # of an ordered list you're processing, for instance). In these
  # cases, we'll use a keyword list to capture the context. Not all
  # directives require this, however; thus, we provide a default
  # implementation with an empty context.
  defp process_directive(directive),
    do: process_directive(directive, [])

  defp process_directive(%{"name" => "attachment", "children" => children}=attachment, _) do
    # Nested attachments are ignored
    {attachment_text, _} = render(children)
    attachment = if Map.get(attachment, "fields", []) == [] do
      Map.delete(attachment, "fields")
    else
      attachment
    end
    attachment
    |> rename_key("title_url", "title_link")
    |> Map.delete("children")
    |> Map.put("text", attachment_text)
    |> Map.put("fallback", attachment_text)
    |> Map.update("color", Colors.name_to_hex("blue"), &(Colors.name_to_hex(&1)))
  end
  defp process_directive(%{"name" => "text", "text" => text}, _),
    do: text
  defp process_directive(%{"name" => "italics", "text" => text}, _),
    do: "_#{text}_"
  defp process_directive(%{"name" => "bold", "text" => text}, _),
    do: "*#{text}*"
  defp process_directive(%{"name" => "fixed_width", "text" => text}, _),
    do: "`#{text}`"
  defp process_directive(%{"name" => "fixed_width_block", "text" => text}, _),
    do: "```#{text}```"

  # Tables _have_ to have a header
  defp process_directive(%{"name" => "table",
                           "children" => [%{"name" => "table_header",
                                            "children" => header}|rows]}, _) do
    headers = map(header)
    case map(rows) do
      [] ->
        # TableRex doesn't currently like tables without
        # rows for some reason... so we get to render an
        # empty table ourselves :/
        "```#{render_empty_table(headers)}```"
      rows ->
        "```#{TableRex.quick_render!(rows, headers)}```"
    end
  end
  defp process_directive(%{"name" => "table_row", "children" => children}, _),
    do: map(children)
  defp process_directive(%{"name" => "table_cell", "children" => children}, _),
    do: Enum.map_join(children, &process_directive/1)
  defp process_directive(%{"name" => "newline"}, _),
    do: "\n"
  defp process_directive(%{"name" => "unordered_list", "children" => children}, _),
    do: Enum.map_join(children, &process_directive(&1, bullet: "•"))
  defp process_directive(%{"name" => "ordered_list", "children" => children}, _) do
    {lines, _} = Enum.map_reduce(children, 1, fn(child, counter) ->
      line = process_directive(child, bullet: "#{counter}.")
      {line, counter + 1}
    end)
    lines
  end
  defp process_directive(%{"name" => "list_item", "children" => children}, bullet: bullet),
    do: "#{bullet} #{Enum.map_join(children, &process_directive/1)}\n"
  defp process_directive(%{"name" => "link", "url" => url}, _) do
    "#{url}"
  end
  defp process_directive(%{"text" => text}=directive, _) do
    Logger.warn("Unrecognized directive; formatting as plain text: #{inspect directive}")
    text
  end
  defp process_directive(%{"name" => "paragraph", "children" => children}, _) do
    Enum.map_join(children, &process_directive/1) <> "\n\n"
  end
  defp process_directive(%{"name" => name}=directive, _) do
    Logger.warn("Unrecognized directive; #{inspect directive}")
    "\nUnrecognized directive: #{name}\n"
  end

  defp rename_key(map, old_key, new_key) do
    {value, map} = Map.pop(map, old_key, :undefined)
    if value == :undefined do
      map
    else
      Map.put(map, new_key, value)
    end
  end

  # Shortcut for processing a list of directives without additional
  # context, since it's so common
  defp map(directives),
    do: Enum.map(directives, &process_directive/1)

  defp consolidate_outputs([], acc), do: acc
  defp consolidate_outputs([h|t], {"", attachments}) when is_binary(h) do
    consolidate_outputs(t, {h, attachments})
  end
  defp consolidate_outputs([h|t], {text, attachments}) when is_binary(h) and is_binary(text) do
    consolidate_outputs(t, {:erlang.list_to_binary([text, h]), attachments})
  end
  defp consolidate_outputs([%{"name" => "attachment"}=attachment|t], {text, attachments}) do
    consolidate_outputs(t, {text, [attachment|attachments]})
  end

  defp finalize_attachment(attachment) do
    attachment
    |> Map.delete("name")
    |> Map.put("mrkdwn_in", Enum.filter(Map.keys(attachment), &(&1 in @markdown_fields)))
  end

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

end

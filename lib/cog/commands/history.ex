defmodule Cog.Commands.History do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "history"

  alias Cog.Repository.PipelineHistory, as: HistoryRepo

  @description "View command history"
  @default_limit 20

  # Allow any user to run history
  rule "when command is #{Cog.Util.Misc.embedded_bundle}:history allow"

  option "limit", short: "l", type: "int", required: false,
    description: "Show <limit> history entries"

  def handle_message(%{options: opts, args: args}=req, state) do
    limit = Map.get(opts, "limit", @default_limit)
    with {:ok, {hist_start, hist_end}} <- parse_args(args)
      do
        case fetch_history(req, hist_start, hist_end, limit) |> format_entries do
          [] ->
            {:reply, req.reply_to, "Empty command history.", state}
          entries ->
            {:reply, req.reply_to, "history-list", entries, state}
        end
      else
        {:error, reason} when is_binary(reason) ->
          {:error, req.reply_to, reason, state}
    end
  end

  defp fetch_history(req, hist_start, hist_end, limit) do
    HistoryRepo.history_for_user(req.user["id"], hist_start, hist_end, limit)
  end

  defp parse_args([]), do: {:ok, {nil, nil}}
  defp parse_args([hist_range]) when is_binary(hist_range) do
    case String.split(hist_range, "-") do
      [hist_start] ->
        with {:ok, parsed} <- parse_int(hist_start),
          do: {:ok, {parsed, nil}}
      ["", hist_end] ->
        with {:ok, parsed} <- parse_int(hist_end),
          do: {:ok, nil, parsed}
      [hist_start, ""] ->
        with {:ok, parsed} <- parse_int(hist_start),
          do: {:ok, {parsed, nil}}
      [hist_start, hist_end] ->
        with {:ok, parsed_start} <- parse_int(hist_start),
             {:ok, parsed_end} <- parse_int(hist_end) do
          # Detect and fix reversed range so DB query still does
          # the right thing
          if parsed_start > parsed_end do
            {:ok, {parsed_end, parsed_start}}
          else
            {:ok, {parsed_start, parsed_end}}
          end
        end
    end
  end
  defp parse_args([hist_start]) when hist_start >= 0 do
    {:ok, {hist_start, nil}}
  end
  defp parse_args([hist_start, hist_end]) when hist_start >=0 and hist_end >= 0 do
    hist_range = if hist_start > hist_end do
      {hist_end, hist_start}
    else
      {hist_start, hist_end}
    end
    {:ok, hist_range}
  end
  defp parse_args(args) do
    {:error, "Invalid history index range args: #{inspect args}"}
  end

  defp parse_int(i) do
    case Integer.parse(i) do
      {v, ""} ->
        {:ok, v}
      _ ->
        {:error, "Invalid number: '#{i}"}
    end
  end

  defp format_entries([]), do: []
  defp format_entries(entries) do
    max_width = find_max_width(entries)
    Enum.map(entries, &(format_entry(&1, max_width)))
  end

  defp format_entry([idx, text], max_width) do
    idx = Integer.to_string(idx)
    count = max_width - String.length(idx)
    %{index: String.pad_leading(idx, count, [" "]),
      text: String.replace(text, "|", "\\|")}
  end

  defp find_max_width(entries) do
    [fidx, _] = List.first(entries)
    [lidx, _] = List.last(entries)
    if lidx > fidx do
      String.length("#{lidx}")
    else
      String.length("#{fidx}")
    end
  end

end

defmodule Cog.Commands.Pipeline.Util do

  alias Cog.Models.PipelineHistory

  @short_id_length 15

  def entry_to_map(entry) do
    %{id: short_id(entry.id),
      user: entry.user.username,
      text: entry.text,
      processed: entry.count,
      state: entry.state,
      started: format_timestamp(entry.started_at),
      elapsed: PipelineHistory.elapsed(entry)}
  end

  def short_id(id) do
    String.slice(id, 0, @short_id_length)
  end

  def format_timestamp(ts) do
    {:ok, ts} = DateTime.from_unix(ts, :milliseconds)
    ts
    |> DateTime.to_iso8601
    |> String.replace(~r/\.[0-9]+Z$/, "Z")
  end

end

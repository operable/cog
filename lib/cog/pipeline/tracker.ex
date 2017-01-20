defmodule Cog.Pipeline.Tracker do

  @pipelines :cog_pipelines
  @max_records 500
  @short_id_length 15

  alias Cog.Events.Util

  require Record

  Record.defrecordp :pipeline, [id: nil, pid: nil, user: nil, text: nil, count: 0, state: :running, started: nil, finished: nil]

  @doc "Configures ETS tables"
  def init() do
    :ets.new(@pipelines, [:set, :public, :named_table, {:keypos, 2}])
  end

  def start_pipeline(id, pid, text, user, started) do
    pline = pipeline(id: id, pid: pid, user: user, text: text, started: started)
    :ets.insert_new(@pipelines, pline)
  end

  def finish_pipeline(id, finished) do
    case :ets.lookup(@pipelines, id) do
      [] ->
        :ok
      [pline] ->
        updated = pline
                  |> pipeline(finished: finished)
                  |> pipeline(state: :finished)
        :ets.insert(@pipelines, updated)
    end
    prune_old_records(@max_records)
  end

  def update_pipeline(id, opts) do
    case :ets.lookup(@pipelines, id) do
      [] ->
        false
      [pline] ->
        updated = update_record(pline, opts)
        :ets.insert(@pipelines, updated)
    end
  end

  def all_pipelines() do
    :ets.tab2list(@pipelines)
    |> Enum.map(&pipeline_to_map/1)
    |> Enum.sort(&by_started/2)
  end

  def pipeline_pid(id) do
    results = if String.length(id) == @short_id_length do
      pipelines_by(short_id: id)
    else
      pipelines_by(id: id)
    end
    case results do
      [] ->
        nil
      [pline] ->
        if pipeline(pline, :state) == :finished do
          nil
        else
          pipeline(pline, :pid)
        end
    end
  end

  def pipelines_by(user: user) do
    :ets.select(@pipelines, [{{:pipeline, :_, :_, user, :_, :_, :_, :_, :_}, [], [:"$_"]}])
    |> Enum.map(&pipeline_to_map/1)
    |> Enum.sort(&by_started/2)
  end
  def pipelines_by(state: state) do
    :ets.select(@pipelines, [{{:pipeline, :_, :_, :_, :_, :_, state, :_, :_}, [], [:"$_"]}])
    |> Enum.map(&pipeline_to_map/1)
    |> Enum.sort(&by_started/2)
  end
  def pipelines_by(id: id) do
    :ets.lookup(@pipelines, id)
  end
  def pipelines_by(short_id: sid) do
    :ets.select(@pipelines, [{{:pipeline, :"$1", :_, :_, :_, :_, :_, :_, :_}, [], [:"$1"]}])
    |> Enum.filter(&(String.starts_with?(&1, sid)))
    |> Enum.flat_map(&(pipelines_by(id: &1)))
  end

  def prune_old_records(max) do
    count = :ets.info(@pipelines, :size)
    if count > max do
      prune_old_records(pipelines_by(state: :finished), count - max)
    end
  end

  defp prune_old_records([], _), do: :ok
  defp prune_old_records(_, 0), do: :ok
  defp prune_old_records([%{id: id}|rest], count) do
    :ets.delete(@pipelines, id)
    prune_old_records(rest, count - 1)
  end

  defp update_record(pline, []), do: pline
  defp update_record(pline, [{:count, v}|rest]) do
    updated = pipeline(pline, :count) + v
    update_record(pipeline(pline, count: updated), rest)
  end
  defp update_record(pline, [{:state, v}|rest]) do
    update_record(pipeline(pline, state: v), rest)
  end

  defp pipeline_to_map(pline) do
    entry = %{id: short_id(pipeline(pline, :id)),
              user: pipeline(pline, :user),
              text: pipeline(pline, :text),
              processed: pipeline(pline, :count),
              state: pipeline(pline, :state),
              started: pipeline(pline, :started)}
    elapsed = case pipeline(pline, :finished) do
                nil ->
                  Util.elapsed(entry.started, DateTime.utc_now(), :milliseconds)
                finished ->
                  Util.elapsed(entry.started, finished, :milliseconds)
              end
    Map.put(entry, :elapsed, elapsed)
    |> Map.put(:started, format_timestamp(entry.started))
  end

  defp short_id(id) do
    String.slice(id, 0, @short_id_length)
  end

  defp by_started(p1, p2) do
    p1.started >= p2.started
  end

  defp format_timestamp(ts) do
    DateTime.to_iso8601(ts) |> String.replace(~r/\.[0-9]+Z$/, "Z")
  end

end

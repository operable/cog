defmodule Cog.Util.ETSWrapper do
  def lookup(table, key) do
    case :ets.lookup(table, key) do
      [{^key, value}] ->
        {:ok, value}
      [] ->
        {:error, :unknown_key}
    end
  end

  def insert(table, key, value) do
    true = :ets.insert(table, {key, value})
    {:ok, value}
  end

  def delete(table, key) do
    case lookup(table, key) do
      {:ok, value} ->
        true = :ets.delete(table, key)
        {:ok, value}
      error ->
        error
    end
  end

  def match_delete(table, query) do
    :ets.match_delete(table, query)
  end

  def each(table, fun) do
    :ets.safe_fixtable(table, true)
    do_each(table, :ets.first(table), fun)
    :ets.safe_fixtable(table, false)
  end

  defp do_each(_table, :'$end_of_table', _fun),
    do: :ok
  defp do_each(table, key, fun) do
    case lookup(table, key) do
      {:ok, value} ->
        fun.(key, value)
      _error ->
        :ok
    end

    do_each(table, :ets.next(table, key), fun)
  end
end

defmodule Cog.Command.Service.Memory do
  @moduledoc """
  Stores state isolated to a specific pipeline. Tokens originally created by
  the token service are used to namespace each key, so pipelines have their own
  keyspace. When the pipeline ends successfully or crashes the memory service
  is notifed, and keys owned by that pipeline are removed.

  There are a few operations that can be performed on keys: fetch, accum, join,
  replace and delete. Each operation will always return an ok-error tuple.
  """

  use GenServer
  alias Cog.Command.Service
  require Logger

  @dead_process_cleanup_interval 30000 # 30 seconds

  defstruct [:memory_table, :monitor_table]

  def start_link(memory_table, monitor_table),
    do: GenServer.start_link(__MODULE__, [memory_table, monitor_table], name: __MODULE__)

  @doc """
  Fetches the given key. Returns `{:ok, value}` if the key exists or `{:error,
  :unknown_key}` if it doesn't exist.
  """
  def fetch(token, key),
    do: GenServer.call(__MODULE__, {:fetch, token, key})

  @doc """
  Accumulates values in the given key. Returns `{:ok, accumulated_value}`. If
  the key exists and is a list, the value is appeneded. If the key exists and
  is not a list, we wrap it in a list before appending the value. If the key
  does not exist we append the value to an empty list.
  """
  def accum(token, key, value),
    do: GenServer.call(__MODULE__, {:accum, token, key, value})

  @doc """
  Joins values in the given key. Returns `{:ok, joined_value}` when the value
  is successfully joined. If the key exists and is a list and the value is a
  list, the value is joined to the end of the list. If the key does not exist,
  the value is joined to an empty list. If either value is not a list `{:error,
  :value_not_list}` is returned.
  """
  def join(token, key, value) when is_list(value),
    do: GenServer.call(__MODULE__, {:join, token, key, value})
  def join(_token, _key, _value),
    do: {:error, :value_not_list}

  @doc """
  Replaces or sets the given key with the value. Returns `{:ok, value}`.
  """
  def replace(token, key, value),
    do: GenServer.call(__MODULE__, {:replace, token, key, value})

  @doc """
  Deletes the given key. Returns `{:ok, deleted_value}` when successfully
  deleted or `{:error, :unknown_key}` if it doesn't exist.
  """
  def delete(token, key),
    do: GenServer.call(__MODULE__, {:delete, token, key})

  def init([memory_table, monitor_table]) do
    # Cleanup processes that died between restarts and monitor processes that
    # are still alive after a restart. If anything dies between restarting and
    # monitoring, the dead process cleanup will catch it.
    account_for_existing_processes(monitor_table, memory_table)
    schedule_dead_process_cleanup(@dead_process_cleanup_interval)

    state = %__MODULE__{memory_table: memory_table, monitor_table: monitor_table}
    {:ok, state}
  end

  def handle_call({:fetch, token, key}, _from, state) do
    result = ets_lookup(state.memory_table, {token, key})
    {:reply, result, state}
  end

  def handle_call({:accum, token, key, value}, _from, state) do
    monitor_executor(state.monitor_table, token)

    result = with {:ok, existing_value}    <- ets_lookup_accum_list(state.memory_table, {token, key}),
                  {:ok, accumulated_value} <- ets_insert(state.memory_table, {token, key}, existing_value ++ [value]),
                  do: {:ok, accumulated_value}

    {:reply, result, state}
  end

  def handle_call({:join, token, key, value}, _from, state) when is_list(value) do
    monitor_executor(state.monitor_table, token)

    result = with {:ok, existing_value}    <- ets_lookup_join_list(state.memory_table, {token, key}),
                  {:ok, accumulated_value} <- ets_insert(state.memory_table, {token, key}, existing_value ++ value),
                  do: {:ok, accumulated_value}

    {:reply, result, state}
  end

  def handle_call({:replace, token, key, value}, _from, state) do
    monitor_executor(state.monitor_table, token)

    result = ets_insert(state.memory_table, {token, key}, value)
    {:reply, result, state}
  end

  def handle_call({:delete, token, key}, _from, state) do
    result = ets_delete(state.memory_table, {token, key})
    {:reply, result, state}
  end

  def handle_info({:DOWN, _monitor_ref, :process, pid, reason}, state) do
    case ets_lookup(state.monitor_table, pid) do
      {:ok, token} ->
        cleanup_process(state.monitor_table, state.memory_table, pid, token)
      {:error, :unknown_key} ->
        Logger.warn("Unknown pid #{inspect pid} was monitored; ignoring")
    end

    {:noreply, state}
  end

  def handle_info(:dead_process_cleanup, state) do
    ets_iterate(state.monitor_table, fn pid, token ->
      unless Process.alive?(pid) do
        cleanup_process(state.monitor_table, state.memory_table, pid, token)
      end
    end)

    schedule_dead_process_cleanup(@dead_process_cleanup_interval)

    {:noreply, state}
  end

  defp account_for_existing_processes(monitor_table, memory_table) do
    ets_iterate(monitor_table, fn pid, token ->
      case Process.alive?(pid) do
        true ->
          Logger.debug("Remonitoring #{inspect pid} for token #{inspect token}")
          :erlang.monitor(:process, pid)
        false ->
          cleanup_process(monitor_table, memory_table, pid, token)
      end
    end)
  end

  defp schedule_dead_process_cleanup(interval) do
    Logger.info ("Scheduling dead process cleanup for #{round(interval / 1000)} from now")
    Process.send_after(self(), :dead_process_cleanup, interval)
  end

  defp cleanup_process(monitor_table, memory_table, pid, token) do
    Logger.debug("Process #{inspect pid} is no longer alive; removing its memory storage")
    :ets.match_delete(memory_table, {{token, :_}, :_})
    :ets.delete(monitor_table, pid)
  end

  defp monitor_executor(monitor_table, token) do
    case Service.Tokens.process_for_token(token) do
      {:error, error} ->
        {:error, error}
      pid ->
        case ets_lookup(monitor_table, pid) do
          {:ok, ^token} ->
            Logger.debug("Already monitoring #{inspect pid} for token #{inspect token}")
          {:error, :unknown_key} ->
            Logger.debug("Monitoring #{inspect pid} for token #{inspect token}")
            :erlang.monitor(:process, pid)
            :ets.insert(monitor_table, {pid, token})
        end
    end
  end

  defp ets_lookup(table, key) do
    case :ets.lookup(table, key) do
      [{^key, value}] ->
        {:ok, value}
      [] ->
        {:error, :unknown_key}
    end
  end

  defp ets_lookup_accum_list(table, key) do
    case :ets.lookup(table, key) do
      [{^key, value}] ->
        {:ok, List.wrap(value)}
      [] ->
        {:ok, []}
    end
  end

  defp ets_lookup_join_list(table, key) do
    case :ets.lookup(table, key) do
      [{^key, value}] when is_list(value) ->
        {:ok, value}
      [{^key, _value}] ->
        {:error, :value_not_list}
      [] ->
        {:ok, []}
    end
  end

  defp ets_insert(table, key, value) do
    with true <- :ets.insert(table, {key, value}),
         do: {:ok, value}
  end

  defp ets_delete(table, key) do
    with {:ok, value} <- ets_lookup(table, key),
         true <- :ets.delete(table, key),
         do: {:ok, value}
  end

  defp ets_iterate(table, fun) do
    :ets.safe_fixtable(table, true)
    ets_iterate(table, :ets.first(table), fun)
    :ets.safe_fixtable(table, false)
  end

  defp ets_iterate(_table, :'$end_of_table', _fun) do
    :ok
  end

  defp ets_iterate(table, key, fun) do
    case ets_lookup(table, key) do
      {:ok, value} ->
        fun.(key, value)
      _error ->
        :ok
    end

    ets_iterate(table, :ets.next(table, key), fun)
  end
end

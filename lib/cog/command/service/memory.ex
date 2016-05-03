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
  import Cog.Command.Service.PipelineMonitor
  alias Cog.ETSWrapper
  require Logger

  @dead_pipeline_cleanup_interval 30000 # 30 seconds

  defstruct [:memory_table, :monitor_table]

  @doc """
  Starts the #{inspect __MODULE__} service. Accepts two public ets table
  ids: one for storing tokens and keeping track of monitored pids.
  """
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
    account_for_existing_pipelines(monitor_table, memory_table, &{&1, :_})
    schedule_dead_pipeline_cleanup(@dead_pipeline_cleanup_interval)

    state = %__MODULE__{memory_table: memory_table, monitor_table: monitor_table}
    {:ok, state}
  end

  def handle_call({:fetch, token, key}, _from, state) do
    result = ETSWrapper.lookup(state.memory_table, {token, key})
    {:reply, result, state}
  end

  def handle_call({:accum, token, key, value}, _from, state) do
    monitor_pipeline(state.monitor_table, token)

    result = with {:ok, existing_value} <- lookup_accum_list(state.memory_table, {token, key}),
                  accumulated_value = existing_value ++ [value],
                  {:ok, result} <- ETSWrapper.insert(state.memory_table, {token, key}, accumulated_value),
                  do: {:ok, result}

    {:reply, result, state}
  end

  def handle_call({:join, token, key, value}, _from, state) when is_list(value) do
    monitor_pipeline(state.monitor_table, token)

    result = with {:ok, existing_value} <- lookup_join_list(state.memory_table, {token, key}),
                  accumulated_value = existing_value ++ value,
                  {:ok, result} <- ETSWrapper.insert(state.memory_table, {token, key}, accumulated_value),
                  do: {:ok, result}

    {:reply, result, state}
  end

  def handle_call({:replace, token, key, value}, _from, state) do
    monitor_pipeline(state.monitor_table, token)

    result = ETSWrapper.insert(state.memory_table, {token, key}, value)
    {:reply, result, state}
  end

  def handle_call({:delete, token, key}, _from, state) do
    result = ETSWrapper.delete(state.memory_table, {token, key})
    {:reply, result, state}
  end

  def handle_info({:DOWN, _monitor_ref, :process, pid, _reason}, state) do
    case ETSWrapper.lookup(state.monitor_table, pid) do
      {:ok, token} ->
        cleanup_pipeline(state.monitor_table, state.memory_table, pid, {token, :_})
      {:error, :unknown_key} ->
        Logger.warn("Unknown pid #{inspect pid} was monitored; ignoring")
    end

    {:noreply, state}
  end

  def handle_info(:dead_process_cleanup, state) do
    dead_pipeline_cleanup(state.monitor_table, state.memory_table)
    schedule_dead_pipeline_cleanup(@dead_pipeline_cleanup_interval)

    {:noreply, state}
  end

  defp lookup_accum_list(table, key) do
    case ETSWrapper.lookup(table, key) do
      {:ok, value} ->
        {:ok, List.wrap(value)}
      {:error, :unknown_key} ->
        {:ok, []}
    end
  end

  defp lookup_join_list(table, key) do
    case ETSWrapper.lookup(table, key) do
      {:ok, value} when is_list(value) ->
        {:ok, value}
      {:ok, _value} ->
        {:error, :value_not_list}
      {:error, :unknown_key} ->
        {:ok, []}
    end
  end
end

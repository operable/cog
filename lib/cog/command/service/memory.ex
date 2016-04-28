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

  defstruct [:tid]

  def start_link(tid),
    do: GenServer.start_link(__MODULE__, [tid], name: __MODULE__)

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

  def init([tid]) do
    Logger.info("Starting with token table #{inspect tid}")
    {:ok, %__MODULE__{tid: tid}}
  end

  def handle_call({:fetch, token, key}, _from, %__MODULE__{tid: tid} = state) do
    result = ets_lookup(tid, {token, key})
    {:reply, result, state}
  end

  def handle_call({:accum, token, key, value}, _from, %__MODULE__{tid: tid} = state) do
    monitor_executor(token, tid)

    result = with {:ok, existing_value}    <- ets_lookup_accum_list(tid, {token, key}),
                  {:ok, accumulated_value} <- ets_insert(tid, {token, key}, existing_value ++ [value]),
                  do: {:ok, accumulated_value}

    {:reply, result, state}
  end

  def handle_call({:join, token, key, value}, _from, %__MODULE__{tid: tid} = state) when is_list(value) do
    monitor_executor(token, tid)

    result = with {:ok, existing_value}    <- ets_lookup_join_list(tid, {token, key}),
                  {:ok, accumulated_value} <- ets_insert(tid, {token, key}, existing_value ++ value),
                  do: {:ok, accumulated_value}

    {:reply, result, state}
  end

  def handle_call({:replace, token, key, value}, _from, %__MODULE__{tid: tid} = state) do
    monitor_executor(token, tid)

    result = ets_insert(tid, {token, key}, value)
    {:reply, result, state}
  end

  def handle_call({:delete, token, key}, _from, %__MODULE__{tid: tid} = state) do
    result = ets_delete(tid, {token, key})
    {:reply, result, state}
  end

  def handle_info({:DOWN, monitor_ref, :process, pid, reason}, %__MODULE__{tid: tid} = state) do 
    Logger.debug("Process #{inspect pid} went down (#{inspect reason}); removing its memory storage")

    case :ets.lookup(tid, monitor_ref) do
      [{^monitor_ref, token}] ->
        :ets.match_delete(tid, {{token, :_}, :_})
        :ets.delete(tid, monitor_ref)
      [] ->
        Logger.warn("Unknown monitor ref #{inspect monitor_ref} for pid #{inspect pid} going down for #{inspect reason}")
    end

    {:noreply, state}
  end

  defp monitor_executor(token, tid) do
    case Service.Tokens.process_for_token(token) do
      {:error, error} ->
        {:error, error}
      pid ->
        Logger.debug("Monitoring #{inspect pid} for token #{inspect token}")
        monitor_ref = :erlang.monitor(:process, pid)
        :ets.insert(tid, {monitor_ref, token})
    end
  end

  defp ets_lookup(tid, key) do
    case :ets.lookup(tid, key) do
      [{^key, value}] ->
        {:ok, value}
      [] ->
        {:error, :unknown_key}
    end
  end

  defp ets_lookup_accum_list(tid, key) do
    case :ets.lookup(tid, key) do
      [{^key, value}] ->
        {:ok, List.wrap(value)}
      [] ->
        {:ok, []}
    end
  end

  defp ets_lookup_join_list(tid, key) do
    case :ets.lookup(tid, key) do
      [{^key, value}] when is_list(value) ->
        {:ok, value}
      [{^key, _value}] ->
        {:error, :value_not_list}
      [] ->
        {:ok, []}
    end
  end

  defp ets_insert(tid, key, value) do
    with true <- :ets.insert(tid, {key, value}),
         do: {:ok, value}
  end

  defp ets_delete(tid, key) do
    with {:ok, value} <- ets_lookup(tid, key),
         true <- :ets.delete(tid, key),
         do: {:ok, value}
  end
end

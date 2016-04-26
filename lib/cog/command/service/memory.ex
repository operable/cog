defmodule Cog.Command.Service.Memory do
  use GenServer
  alias Cog.Command.Service
  require Logger

  defstruct [:tid]

  def start_link(tid),
    do: GenServer.start_link(__MODULE__, [tid], name: __MODULE__)

  def fetch(token, key),
    do: GenServer.call(__MODULE__, {:fetch, token, key})

  def accum(token, key, value),
    do: GenServer.call(__MODULE__, {:accum, token, key, value})

  def replace(token, key, value),
    do: GenServer.call(__MODULE__, {:replace, token, key, value})

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

    result = with {:ok, existing_value}    <- ets_lookup_list(tid, {token, key}),
                  {:ok, accumulated_value} <- ets_insert(tid, {token, key}, existing_value ++ [value]),
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

  defp ets_lookup_list(tid, key) do
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
    with {:ok, value} <- :ets.insert(tid, {key, value}),
         do: {:ok, value}
  end

  defp ets_delete(tid, key) do
    with {:ok, value} <- ets_lookup(tid, key),
         true <- :ets.delete(tid, key),
         do: {:ok, value}
  end
end

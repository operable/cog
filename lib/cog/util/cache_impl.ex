defmodule Cog.Util.CacheImpl do

  @cache_config_key :__CACHE_CONFIG__

  use GenServer
  alias Cog.Util.TimeHelpers

  defstruct [:tid, :tref]

  def start_link(args) do
    name = Keyword.get(args, :name) || __MODULE__
    GenServer.start_link(__MODULE__, [args], name: name)
  end

  def lookup(cacheref, key) when is_atom(cacheref) do
    current_time = TimeHelpers.now()
    case :ets.lookup(cacheref, key) do
      [{^key, expiry, value}] when expiry > current_time ->
        {:ok, value}
      _ ->
        {:ok, nil}
    end
  end

  def store(cacheref, key, value) do
    GenServer.call(cacheref, {:store, key, value}, :infinity)
  end

  def delete(cacheref, key) do
    GenServer.call(cacheref, {:delete, key}, :infinity)
  end

  def close(cacheref) do
    GenServer.stop(cacheref, :shutdown)
  end

  def init([args]) do
    name = Keyword.fetch!(args, :name)
    ttl = Keyword.fetch!(args, :ttl)
    tid = :ets.new(name, [:set, :protected, :named_table, {:read_concurrency, true}])
    :ets.insert_new(tid, {@cache_config_key, [ttl: ttl]})
    {:ok, tref} = if ttl > 0 do
      :timer.send_interval((ttl * 2000), :expire)
    else
      {:ok, nil}
    end
    {:ok, %__MODULE__{tid: tid, tref: tref}}
  end

  def handle_call({:store, key, value}, _from, state) do
    ttl = get_cache_ttl(state.tid)
    reply = if ttl > 0 do
      expiry = ttl + TimeHelpers.now()
      case :ets.insert(state.tid, {key, expiry, value}) do
        true ->
          :ok
        false ->
          {:error, :store_failed}
      end
    else
      :ok
    end
    {:reply, reply, state}
  end
  def handle_call({:delete, key}, _from, state) do
    ttl = get_cache_ttl(state.tid)
    reply = if ttl > 0 do
      case :ets.lookup(state.tid, key) do
        [] ->
          false
        [_] ->
          :ets.delete(state.tid, key)
      end
    else
      true
    end
    {:reply, reply, state}
  end

  def handle_info(:expire, state) do
    current_time = TimeHelpers.now()
    :ets.safe_fixtable(state.tid, true)
    expire_old_entries(state.tid, current_time)
    :ets.safe_fixtable(state.tid, false)
    {:noreply, state}
  end

  defp get_cache_ttl(cacheref) do
    [{_, config}] = :ets.lookup(cacheref, @cache_config_key)
    Keyword.get(config, :ttl)
  end

  defp expire_old_entries(tid, older_than) do
    expire_old_entries(tid, :ets.first(tid), older_than)
  end
  defp expire_old_entries(tid, @cache_config_key, older_than) do
    expire_old_entries(tid, :ets.next(tid, @cache_config_key), older_than)
  end
  defp expire_old_entries(_tid, :'$end_of_table', _older_than), do: :ok
  defp expire_old_entries(tid, key, older_than) do
    [{_, expiry, _}] = :ets.lookup(tid, key)
    unless expiry >= older_than do
      :ets.delete(tid, key)
    end
    expire_old_entries(tid, :ets.next(tid, key), older_than)
  end
end

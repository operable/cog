defmodule Cog.TemplateCache do
  use GenServer
  alias Cog.Config
  alias Cog.Time
  require Logger

  defstruct [:ttl, :tref]

  @ets_table :template_cache

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    :ets.new(@ets_table, [:ordered_set, :protected, :named_table, {:read_concurrency, true}])

    ttl = fetch_ttl()
    {:ok, tref} = if ttl > 0 do
      :timer.send_interval(ttl * 1500, :expire_cache)
    else
      {:ok, nil}
    end

    Logger.info("#{__MODULE__} intialized. Template cache TTL is #{ttl} seconds.")
    {:ok, %__MODULE__{ttl: ttl, tref: tref}}
  end

  def lookup(adapter, bundle_id, template) do
    GenServer.call(__MODULE__, {:lookup, adapter, bundle_id, template})
  end

  def insert(adapter, bundle_id, template, template_fun) do
    GenServer.call(__MODULE__, {:insert, adapter, bundle_id, template, template_fun})
  end

  def handle_call({:lookup, adapter, bundle_id, template}, _from, state) do
    expires_before = Time.now

    result = case :ets.lookup(@ets_table, {adapter, bundle_id, template}) do
      [{{^adapter, ^bundle_id, ^template}, value, expiry}] when expiry > expires_before ->
        {:ok, value}
      _ ->
        :error
    end

    {:reply, result, state}
  end

  def handle_call({:insert, adapter, bundle_id, template, template_fun}, _from, state) do
    expiry = Time.now + state.ttl
    :ets.insert(@ets_table, {{adapter, bundle_id, template}, template_fun, expiry})
    {:reply, :ok, state}
  end

  def handle_info(:expire_cache, state) do
    expire_old_entries
    {:noreply, state}
  end

  defp expire_old_entries do
    :ets.safe_fixtable(@ets_table, true)
    drop_old_entries(:ets.first(@ets_table), Time.now)
    :ets.safe_fixtable(@ets_table, false)
  end

  defp drop_old_entries(:'$end_of_table', _),
    do: :ok
  defp drop_old_entries(key, time) do
    case :ets.lookup(@ets_table, key) do
      [{_, _, expiry}] when expiry < time ->
        :ets.delete(@ets_table, key)
      _ ->
        :ok
    end
    drop_old_entries(:ets.next(@ets_table, key), time)
  end

  defp fetch_ttl do
    ttl = Application.get_env(:cog, :template_cache_ttl, {60, :sec})
    Config.convert(ttl, :sec)
  end
end

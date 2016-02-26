defmodule Cog.Command.BundleCache do
  @moduledoc """
  Caches for the current enabled/disabled status for bundles.
  """

  @ets_table :bundle_cache

  @opaque t :: %__MODULE__{ttl: pos_integer,
                           tref: :timer.tref,
                           table: atom}
  defstruct [ttl: 1,
             tref: nil,
             table: @ets_table]

  use GenServer
  use Adz

  alias Cog.Repo
  alias Cog.Models.Bundle

  # Expired entries are removed with a period that is some multiple of
  # the TTL; e.g., if the TTL is 60 seconds, a multiplier of 3 would
  # result in purges every 3 minutes.
  @purge_multiplier 3

  @doc """
  Retrieve the current activation status of the given bundle.
  """
  @spec status(String.t) :: {:ok, :enabled | :disabled} | {:error, term}
  def status(bundle_name) do
    case lookup(@ets_table, bundle_name) do
      {:ok, status} ->
        Logger.debug("Found cached value for key `#{bundle_name}`: #{status}")
        {:ok, status}
      :not_found ->
        Logger.debug("Cache miss for key `#{bundle_name}`")
        GenServer.call(__MODULE__, {:status, bundle_name})
    end
  end

  def init(_) do
    new_ets_cache_table(@ets_table)
    ttl = resolve_ttl_in_seconds!(:bundle_cache_ttl)
    {:ok, tref, purge_period} = purge_timer(ttl, @purge_multiplier)
    Logger.info("Ready. Bundle cache TTL is #{ttl} seconds, with purges every #{purge_period} seconds")
    {:ok, %__MODULE__{ttl: ttl, tref: tref, table: @ets_table}}
  end

  def handle_call({:status, bundle_name}, _caller, state) do
    reply = case Repo.get_by(Bundle, name: bundle_name) do
              nil ->
                {:error, {:no_bundle, bundle_name}}
              bundle ->
                cache_item = cache_item(bundle.name, bool_to_status(bundle.enabled), state.ttl)
                cached_value = cache(cache_item, state.table)
                {:ok, cached_value}
            end
    {:reply, reply, state}
  end

  defp bool_to_status(true),  do: :enabled
  defp bool_to_status(false), do: :disabled

  ########################################################################
  # Generic Functions: Everything from here onward is fair game for a
  # generic cache behaviour

  def start_link(),
    do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  ########################################################################
  # Configuration

  defp resolve_ttl_in_seconds!(config_key) do
    ttl = :cog
    |> Application.get_env(config_key, {60, :sec})
    |> Cog.Config.convert(:sec)

    if ttl <= 0,
      do: raise("Must specify a non-zero positive integer for `#{config_key}`")
    ttl
  end

  ########################################################################
  # Cache Structure

  defp new_ets_cache_table(table_name) do
    :ets.new(table_name, [:ordered_set,
                          :protected,
                          :named_table,
                          {:read_concurrency, true}])
  end

  defp lookup(table, key) do
    now = Cog.Time.now
    case :ets.lookup(table, key) do
      [{^key, value, expiration}] when expiration > now ->
        {:ok, value}
      _ ->
        :not_found
    end
  end

  defp cache({_k, value, _expiration}=cache_item, table) do
    :ets.insert(table, cache_item)
    value
  end

  defp cache_item(key, value, ttl),
    do: {key, value, expiration(ttl)}

  ########################################################################
  # Expired Entry Purging

  defp purge_timer(ttl, multiplier) do
    purge_period = ttl * multiplier
    {:ok, tref} = :timer.send_interval(purge_period * 1000, :purge_cache) # timers need milliseconds
    {:ok, tref, purge_period} # humans care about seconds, though
  end

  def handle_info(:purge_cache, state) do
    purge_expired(state.table)
    {:noreply, state}
  end
  def handle_info(_, state),
    do: {:noreply, state}

  defp expiration(ttl),
    do: Cog.Time.now + ttl

  defp purge_expired(table),
    do: purge_expired(table, Cog.Time.now, :ets.first(table))

  defp purge_expired(_table, _now, :'$end_of_table'),
    do: true
  defp purge_expired(table, now, key) do
    case :ets.lookup(table, key) do
      [{^key, _value, expiration}] when expiration < now ->
        Logger.debug("Purging expired cache entry for `#{key}`")
        :ets.delete(table, key);
      _ ->
        true
    end
    purge_expired(table, now, :ets.next(table, key))
  end

end

defmodule Cog.Command.PermissionsCache do
  defstruct [:ttl, :tref]
  use GenServer
  require Logger

  @ets_table :cog_perms_cache

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def fetch(user) do
    expires_before = Cog.Time.now()
    key = user.id
    case :ets.lookup(@ets_table, key) do
      [{^key, perms, expiry}] when expiry > expires_before ->
        {:ok, perms}
      _ ->
        GenServer.call(__MODULE__, {:fetch, user}, :infinity)
    end
  end

  def reset_cache do
    GenServer.call(__MODULE__, :reset_cache, :infinity)
  end

  def init(_) do
    :ets.new(@ets_table, [:ordered_set, :protected, :named_table, {:read_concurrency, true}])
    ttl = Cog.Config.convert(Application.get_env(:cog, :user_perms_ttl, {60, :sec}), :sec)
    {:ok, tref} = if ttl > 0 do
      :timer.send_interval((ttl * 1500), :expire_cache)
    else
      {:ok, nil}
    end
    Logger.info("Ready. Cache TTL is #{ttl} seconds.")
    {:ok, %__MODULE__{ttl: ttl, tref: tref}}
  end

  def handle_call({:fetch, user}, _caller, state) do
    expires_before = Cog.Time.now()
    key = user.id
    reply = case :ets.lookup(@ets_table, key) do
              [] ->
                fetch_and_cache(user, state)
              [{_, _, expiry}] when expiry < expires_before ->
                fetch_and_cache(user, state)
              [{^key, perms, _}] ->
                {:ok, perms}
            end
    {:reply, reply, state}
  end

  def handle_call(:reset_cache, _caller, state) do
    :ets.delete_all_objects(@ets_table)
    {:reply, true, state}
  end

  def handle_info(:expire_cache, state) do
    expire_old_entries()
    {:noreply, state}
  end

  defp expire_old_entries() do
    :ets.safe_fixtable(@ets_table, true)
    drop_old_entries(:ets.first(@ets_table), Cog.Time.now())
    :ets.safe_fixtable(@ets_table, false)
  end

  defp drop_old_entries(:'$end_of_table', _) do
    :ok
  end
  defp drop_old_entries(key, time) do
    case :ets.lookup(@ets_table, key) do
      [{_, _, expiry}] when expiry < time ->
        :ets.delete(@ets_table, key)
      _ ->
        :ok
    end
    drop_old_entries(:ets.next(@ets_table, key), time)
  end

  defp fetch_and_cache(user, state) do
    Logger.info("Permission cache miss for user #{user.username}")
    perms = Cog.Models.User.all_permissions(user)
    expiry = Cog.Time.now() + state.ttl
    :ets.insert(@ets_table, {user.id, perms, expiry})
    {:ok, perms}
  end
end

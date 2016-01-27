defmodule Cog.Command.RuleCache do
  defstruct [:ttl, :tref]
  use GenServer
  require Logger

  alias Cog.Repo
  alias Cog.Queries

  @ets_table :cog_rule_cache

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def fetch(command) when is_binary(command) do
    expires_before = Cog.Time.now()
    case :ets.lookup(@ets_table, command) do
      [{^command, value, expiry}] when expiry > expires_before ->
        {:ok, value}
      _ ->
        GenServer.call(__MODULE__, {:fetch, command})
    end
  end

  def init(_) do
    :ets.new(@ets_table, [:ordered_set, :protected, :named_table, {:read_concurrency, true}])
    ttl = Cog.Config.convert(Application.get_env(:cog, :command_rule_ttl, {60, :sec}), :sec)
    {:ok, tref} = if ttl > 0 do
      :timer.send_interval((ttl * 1500), :expire_cache)
    else
      {:ok, nil}
    end
    Logger.info("Ready. Command rule cache TTL is #{ttl} seconds.")
    {:ok, %__MODULE__{ttl: ttl, tref: tref}}
  end

  def handle_call({:fetch, command}, _caller, state) do
    expires_before = Cog.Time.now()
    reply = case :ets.lookup(@ets_table, command) do
              [{^command, value, expiry}] when expiry > expires_before ->
                {:ok, value}
              _ ->
                fetch_and_cache(command, state)
            end
    {:reply, reply, state}
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

  defp fetch_and_cache(command, state) do
    rules = Repo.all(Queries.Command.rules_for_cmd(command)) |>
              Enum.sort_by(&(&1.score), &>/2)
    Repo.preload rules, [permissions: :namespace]
    add_to_cache(command, rules, state.ttl)
    {:ok, rules}
  end

  defp add_to_cache(_command, [], _) do
    :ok
  end
  defp add_to_cache(_command, _rules, 0) do
    :ok
  end
  defp add_to_cache(command, rules, ttl) do
    expiry = Cog.Time.now() + ttl
    :ets.insert(@ets_table, {command, rules, expiry})
    end


end

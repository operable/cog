defmodule Cog.Command.CommandCache do
  @moduledoc """
  Caches commands and their options

  Commands are cached automatically when they or their options are fetched.

  ## Configuration

  The ttl for the cache is configurable via `:command_cache_ttl`. If not set the
  default is 60sec. To disable the cache set `:command_cache_ttl` to `0`.

  ## State

  :ttl - Time to live for items in the cache. Configured with `:command_cache_ttl`,
         default value is `{60, sec}`. Disabled when set to `0`.
  :tref - Reference to the cache expiration timer. Set to nil when the cache is
          disabled.
  """

  defstruct [:ttl, :tref]
  use GenServer
  require Logger

  alias Cog.Repo
  alias Cog.Queries
  alias Cog.Models.CommandOption
  alias Piper.Command.Ast

  @ets_table :command_cache

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Fetch a command record

  `#{inspect __MODULE__}.fetch/1`

  Takes an `%Ast.Invocation{}` and returns {:ok, %Cog.Models.Command{}} or the
  atom :not_found. Command records are cached on successful retrieval.
  """
  def fetch(%Ast.Invocation{command: command_name}) do
    case lookup(command_name) do
      {:ok, command} ->
        {:ok, command}
      :not_found ->
        GenServer.call(__MODULE__, {:fetch, command_name})
    end
  end

  @doc """
  Fetch a commands options

  `#{inspect __MODULE__}.fetch_options/2`

  Takes an `%Ast.Invocation{}` and an atom of :prepared or :options. Returns a
  command's option's as a list (:options) or a map prepared for option
  interpretation (:prepared).
  """
  def fetch_options(%Ast.Invocation{command: command_name}, which) when which in [:prepared, :options] do
    case lookup_options(command_name, which) do
      {:ok, options} ->
        {:ok, options}
      :not_found ->
        case GenServer.call(__MODULE__, {:fetch, command_name}) do
          {:ok, command} ->
            {:ok, get_options(command, which)}
          {:not_found, _} ->
            :not_found
        end
    end
  end

  def init(_) do
    :ets.new(@ets_table, [:ordered_set, :protected, :named_table, {:read_concurrency, true}])
    ttl = Cog.Config.convert(Application.get_env(:cog, :command_cache_ttl, {60, :sec}), :sec)
    {:ok, tref} = if ttl > 0 do
      :timer.send_interval((ttl * 3000), :expire_cache)
    else
      {:ok, nil}
    end
    Logger.info("#{__MODULE__} intialized. Command cache TTL is #{ttl} seconds.")
    {:ok, %__MODULE__{ttl: ttl, tref: tref}}
  end

  def handle_call({:fetch, command_name}, _caller, state) do
    case get_command(command_name) do
      {:ok, command} ->
        true = maybe_cache_command(command, state)
        {:reply, {:ok, command}, state}
      {:not_found, command_name} ->
        {:reply, {:not_found, command_name}, state}
    end
  end

  def handle_info(:expire_cache, state) do
    expire_old_entries()
    {:noreply, state}
  end
  def handle_info(_, state) do
    {:noreply, state}
  end

  defp get_command(name) do
    case Repo.one(Queries.Command.named(name)) do
      nil ->
        {:not_found, name}
      command ->
        preloaded_command = command
        |> Repo.preload([:bundle, options: :option_type])

        {:ok, preloaded_command}
    end
  end

  defp maybe_cache_command(_, %__MODULE__{tref: nil}), do: true
  defp maybe_cache_command(command, %__MODULE__{ttl: ttl}) do
    expiry = Cog.Time.now() + ttl
    name = Cog.Models.Command.full_name(command)
    :ets.insert(@ets_table, {{name, :prepared}, get_options(command, :prepared), expiry}) &&
    :ets.insert(@ets_table, {{name, :options}, get_options(command, :options), expiry}) &&
    :ets.insert(@ets_table, {name, command, expiry})
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
      {_, _, expiry} when expiry < time ->
        :ets.delete(@ets_table, key)
      _ ->
        :ok
    end
    drop_old_entries(:ets.next(@ets_table, key), time)
  end

  defp get_options(%Cog.Models.Command{}=command, :options) do
    command.options
  end
  defp get_options(%Cog.Models.Command{}=command, :prepared) do
    Enum.reduce(command.options, %{}, &(prepare_option(&1, &2)))
  end

  defp prepare_option(%CommandOption{long_flag: lflag, short_flag: nil}=opt, acc) do
    Map.put(acc, lflag, opt)
  end
  defp prepare_option(%CommandOption{long_flag: nil, short_flag: sflag}=opt, acc) do
    Map.put(acc, sflag, opt)
  end
  defp prepare_option(%CommandOption{long_flag: lflag, short_flag: sflag}=opt, acc) do
    acc
    |> Map.put(lflag, opt)
    |> Map.put(sflag, opt)
  end

  defp lookup(command_name) do
    expires_before = Cog.Time.now()
    case :ets.lookup(@ets_table, command_name) do
      [{^command_name, command, expiry}] when expiry > expires_before ->
        {:ok, command}
      _ ->
        :not_found
    end
  end

  defp lookup_options(command_name, which) do
    expires_before = Cog.Time.now()
    case :ets.lookup(@ets_table, {command_name, which}) do
      [{{^command_name, ^which}, value, expiry}] when expiry > expires_before ->
        {:ok, value}
      _ ->
        :not_found
    end
  end
end

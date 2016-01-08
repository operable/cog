defmodule Cog.TemplateCache do
  use GenServer
  alias Cog.Queries.Template
  alias Cog.Repo
  alias Cog.Time
  require Logger

  defstruct [:ttl, :tref]

  @ets_table :template_cache

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    :ets.new(@ets_table, [:ordered_set, :protected, :named_table, {:read_concurrency, true}])

    ttl = Cog.Config.convert(Application.get_env(:cog, :template_cache_ttl, {60, :sec}), :sec)
    {:ok, tref} = if ttl > 0 do
      :timer.send_interval((ttl * 1500), :expire_cache)
    else
      {:ok, nil}
    end

    Logger.info("#{__MODULE__} intialized. Template cache TTL is #{ttl} seconds.")
    {:ok, %__MODULE__{ttl: ttl, tref: tref}}
  end

  def lookup(_bundle, _adapter, "raw") do
    fn context ->
      inspect(context)
    end
  end

  def lookup(_bundle, _adapter, "text") do
    fn context ->
      case context do
        %{"body" => body} ->
          body
        text ->
          text
      end
    end
  end

  def lookup(_bundle, "Slack", "json") do
    fn context ->
      text = Poison.encode!(context, pretty: true)
      "```#{text}```"
    end
  end

  def lookup(_bundle, "HipChat", "json") do
    fn context ->
      text = Poison.encode!(context, pretty: true)
      "/code #{text}"
    end
  end

  def lookup(_bundle, "websocket", "json") do
    fn context ->
      text = Poison.encode!(context, pretty: true)
      "<pre>#{text}</pre>"
    end
  end

  def lookup(_bundle, _adapter, "json") do
    fn context ->
      Poison.encode!(context, pretty: true)
    end
  end

  def lookup(bundle, adapter, template) do
    {:ok, fun} = GenServer.call(__MODULE__, {:lookup, bundle, adapter, template})
    fun
  end

  def handle_call({:lookup, bundle, adapter, template}, _from, state) do
    expires_before = Time.now
    adapter = adapter_key_to_dir(adapter)

    reply = case :ets.lookup(@ets_table, {bundle, adapter, template}) do
      [{{^bundle, ^adapter, ^template}, value, expiry}] when expiry > expires_before ->
        {:ok, value}
      _ ->
        fetch_and_cache(bundle, adapter, template, state)
    end

    {:reply, reply, state}
  end

  def handle_info(:expire_cache, state) do
    expire_old_entries
    {:noreply, state}
  end

  defp fetch_and_cache(bundle, adapter, template, state) do
    source = Template.template_source(bundle, adapter, template) |> Repo.one!
    template_fun = FuManchu.Compiler.compile!(source)

    wrapped_fun = fn context ->
      template_fun.(%{context: context, partials: []})
    end

    expiry = Cog.Time.now + state.ttl
    :ets.insert(@ets_table, {{bundle, adapter, template}, wrapped_fun, expiry})

    {:ok, wrapped_fun}
  end

  defp expire_old_entries do
    :ets.safe_fixtable(@ets_table, true)
    drop_old_entries(:ets.first(@ets_table), Cog.Time.now)
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

  defp adapter_key_to_dir(key),
    do: String.downcase(key)
end

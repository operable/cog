defmodule Cog.Chat.Adapter do

  require Logger

  use Carrier.Messaging.GenMqtt

  @adapter_topic "bot/chat/adapter"
  @incoming_topic "bot/chat/adapter/incoming"

  defstruct [:providers, :samples, :averages]

  @max_samples 100
  @max_averages 5
  @stats_interval 15000 # 15 seconds

  def start_link() do
    GenMqtt.start_link(__MODULE__, [], name: __MODULE__)
  end

  def recalc_stats() do
    GenMqtt.admin(__MODULE__, :recalc_stats)
  end

  def stats() do
    GenMqtt.call(@adapter_topic, :stats, %{}, :infinity)
  end
  def stats(conn) do
    GenMqtt.call(conn, @adapter_topic, :stats, %{}, :infinity)
  end

  def lookup_user(provider, handle) when is_binary(handle) do
    GenMqtt.call(@adapter_topic, :lookup_user, %{provider: provider, handle: handle}, :infinity)
  end
  def lookup_user(conn, provider, handle) when is_binary(handle) do
    GenMqtt.call(conn, @adapter_topic, :lookup_user, %{provider: provider, handle: handle}, :infinity)
  end


  def list_joined_rooms(provider) do
    GenMqtt.call(@adapter_topic, :list_joined_rooms, %{provider: provider}, :infinity)
  end
  def list_joined_rooms(conn, provider) do
    GenMqtt.call(conn, @adapter_topic, :list_joined_rooms, %{provider: provider}, :infinity)
  end


  def join(provider, room) when is_binary(room) do
    GenMqtt.call(@adapter_topic, :join, %{provider: provider, room: room}, :infinity)
  end
  def join(conn, provider, room) when is_binary(room) do
    GenMqtt.call(conn, @adapter_topic, :join, %{provider: provider, room: room}, :infinity)
  end

  def leave(provider, room) when is_binary(room) do
    GenMqtt.call(@adapter_topic, :leave, %{provider: provider, room: room}, :infinity)
  end
  def leave(conn, provider, room) when is_binary(room) do
    GenMqtt.call(conn, @adapter_topic, :leave, %{provider: provider, room: room}, :infinity)
  end


  def list_providers() do
    GenMqtt.call(@adapter_topic, :list_providers, %{}, :infinity)
  end
  def list_providers(conn) do
    GenMqtt.call(conn, @adapter_topic, :list_providers, %{}, :infinity)
  end


  def send(provider, target, message) do
    GenMqtt.cast(@adapter_topic, :send, %{provider: provider, target: target, message: message})
  end
  def send(conn, provider, target, message) do
    GenMqtt.cast(conn, @adapter_topic, :send, %{provider: provider, target: target, message: message})
  end

  def init(conn, _) do
    Logger.info("Starting")
    case Application.fetch_env(:cog, __MODULE__) do
      :error ->
        {:error, :missing_chat_adapter_config}
      {:ok, config} ->
        case Keyword.get(config, :providers) do
          nil ->
            {:error, :missing_chat_provider_name}
          names ->
            case resolve_provider_names(names) do
              {:error, _}=error ->
                error
              providers ->
                finish_initialization(conn, providers)
            end
        end
    end
  end

  # RPC calls
  def handle_call(_conn, @adapter_topic, _sender, %{"stats" => %{}}, state) do
    {:reply, %{stats: %{average_inbound: state.averages}}, state}
  end
  def handle_call(_conn, @adapter_topic, _sender, %{"lookup_user" => %{"provider" => provider,
                                                                     "handle" => handle}}, state) do
    {:reply, with_provider(provider, state, {:lookup_user, [handle]}), state}
  end
  def handle_call(_conn, @adapter_topic, _sender, %{"list_joined_rooms" => %{"provider" => provider}}, state) do
    {:reply, with_provider(provider, state, {:list_joined_rooms, []}), state}
  end
  def handle_call(_conn, @adapter_topic, _sender, %{"join" => %{"provider" => provider,
                                                              "room" => room}}, state) do
    {:reply, with_provider(provider, state, {:join, [room]}), state}
  end
  def handle_call(_conn, @adapter_topic, _sender, %{"leave" => %{"provider" => provider,
                                                               "room" => room}}, state) do
    {:reply, with_provider(provider, state, {:leave, [room]}), state}
  end
  def handle_call(_conn, @adapter_topic, _sender, %{"list_providers" => %{}}, state) do
    {:reply, {:ok, %{providers: Enum.filter(Map.keys(state.providers), &(is_binary(&1)))}}, state}
  end

  # Non-blocking "cast" messages
  def handle_cast(_conn, @adapter_topic, %{"send" => %{"target" => target,
                                                       "message" => message,
                                                       "provider" => provider}}, state) do
    result = with_provider(provider, state, {:send_message, [target, message]})
    Logger.debug("Sent message via #{provider}: #{inspect result}")
    {:noreply, state}
  end
  def handle_cast(_conn, @incoming_topic, %{"event" => event}, state) do
    Logger.debug("Received chat event: #{inspect event}")
    {:noreply, state}
  end
  def handle_cast(_conn, @incoming_topic, %{"message" => msg}, state) do
    Logger.debug("Received chat message: #{inspect msg}")
    sample = :os.system_time(:milli_seconds) - msg["ts"]
    {:noreply, store_sample(state, sample)}
  end

  def handle_admin(:recalc_stats, state) do
    {:noreply, calc_average(state)}
  end

  defp store_sample(%__MODULE__{samples: samples}=state, sample) when length(samples) < @max_samples do
    %{state | samples: [sample|state.samples]}
  end
  defp store_sample(%__MODULE__{samples: samples}=state, sample) do
    samples = Enum.slice(samples, 0, @max_samples - 2)
    %{state | samples: [sample|samples]}
  end

  defp calc_average(%__MODULE__{samples: samples, averages: averages}=state) when length(averages) < @max_averages do
    avg = average_samples(samples)
    %{state | averages: [avg|state.averages]}
  end
  defp calc_average(%__MODULE__{samples: samples, averages: averages}=state) do
    avg = average_samples(samples)
    averages = Enum.slice(samples, 0, @max_averages - 2)
    %{state | averages: [avg|averages]}
  end

  defp average_samples([]), do: 0.0
  defp average_samples(samples), do: round(Enum.sum(samples) / length(samples))

  defp resolve_provider_names(names) do
    Enum.reduce_while(names, [],
      fn(name, acc) ->
        case resolve_provider_name(name) do
          {:ok, provider} ->
            {:cont, [{name, provider}|acc]}
          error ->
            {:halt, error}
        end end)
  end

  defp finish_initialization(conn, providers) do
    Connection.subscribe(conn, @adapter_topic)
    Connection.subscribe(conn, @incoming_topic)
    case start_providers(providers, %{}) do
      {:ok, providers} ->
        :timer.apply_interval(@stats_interval, __MODULE__, :recalc_stats, [])
        {:ok, %__MODULE__{providers: providers, samples: [], averages: []}}
      error ->
        error
    end
  end

  defp start_providers([], accum), do: {:ok, accum}
  defp start_providers([{name, provider}|t], accum) do
    case Application.fetch_env(:cog, provider) do
      :error ->
        {:error, {:missing_provider_config, provider}}
      {:ok, config} ->
        config = [{:incoming_topic, @incoming_topic}|config]
        case provider.start_link(config) do
          {:ok, _} ->
            Logger.info("Chat provider '#{name}' (#{provider}) initialized.")
            accum = accum |> Map.put(name, provider) |> Map.put(Atom.to_string(name), provider)
            start_providers(t, accum)
          error ->
            Logger.error("Chat provider '#{name}' (#{provider}) failed to initialize: #{inspect error}")
            error
        end
    end
  end


  defp resolve_provider_name(:slack), do: {:ok, Cog.Chat.SlackProvider}
  defp resolve_provider_name(:http), do: {:ok, Cog.Chat.HttpProvider}
  defp resolve_provider_name(name), do: {:error, {:unknown_chat_provider, name}}

  defp with_provider(provider, state, {fun, args}) when is_atom(fun) and is_list(args) do
    case Map.get(state.providers, provider) do
      nil ->
        {:error, :unknown_provider}
      provider ->
        apply(provider, fun, args)
    end
  end

end

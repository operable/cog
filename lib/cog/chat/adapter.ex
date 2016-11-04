defmodule Cog.Chat.Adapter do

  require Logger

  use Carrier.Messaging.GenMqtt
  alias Cog.Util.CacheSup
  alias Cog.Util.Cache
  alias Cog.Chat.Ingestor
  alias Cog.Chat.Room
  alias Cog.Chat.User

  @adapter_topic "bot/chat/adapter"
  @cache_name :cog_chat_adapter_cache

  defstruct [:providers, :cache]

  def start_link() do
    GenMqtt.start_link(__MODULE__, [], name: __MODULE__)
  end

  def mention_name(provider, handle) when is_binary(handle) do
    GenMqtt.with_connection(&(mention_name(&1, provider, handle)))
  end
  def mention_name(conn, provider, handle) when is_binary(handle) do
    GenMqtt.call(conn, @adapter_topic , "mention_name", %{provider: provider, handle: handle}, :infinity)
  end

  def display_name(provider) do
    GenMqtt.with_connection(&(display_name(&1, provider)))
  end
  def display_name(conn, provider) do
    GenMqtt.call(conn, @adapter_topic, "display_name", %{provider: provider}, :infinity)
  end

  def lookup_user(provider, handle) when is_binary(handle) do
    GenMqtt.with_connection(&(lookup_user(&1, provider, handle)))
  end
  def lookup_user(conn, provider, handle) when is_binary(handle) do
    cache = get_cache
    case cache[{provider, :user, handle}] do
      nil ->
        case GenMqtt.call(conn, @adapter_topic, "lookup_user", %{provider: provider, handle: handle}, :infinity) do
          {:ok, user} ->
            User.from_map(user)
          {:error, _}=error ->
            error
        end
      {:ok, value} ->
        User.from_map(value)
    end
  end

  # Declaring like this so we fail quickly if lookup_room
  # is called with something other than a keyword list.
  def lookup_room(provider, name: name),
    do: do_lookup_room(provider, name: name)
  def lookup_room(provider, id: id),
    do: do_lookup_room(provider, id: id)

  # room_identifier should come in as a keyword list with
  # either [id: id] or [name: name]
  defp do_lookup_room(provider, room_identifier) do
    GenMqtt.with_connection(&(do_lookup_room(&1, provider, room_identifier)))
  end

  defp do_lookup_room(conn, provider, room_identifier) do
    args = Enum.into(room_identifier, %{provider: provider})
    cache = get_cache
    case cache[{provider, :room, room_identifier}] do
      nil ->
        case GenMqtt.call(conn, @adapter_topic , "lookup_room", args, :infinity) do
          {:ok, room} ->
            Room.from_map(room)
          {:error, _}=error ->
            error
        end
      {:ok, value} ->
        Room.from_map(value)
    end
  end

  def list_joined_rooms(provider) do
    GenMqtt.with_connection(&(list_joined_rooms(&1, provider)))
  end
  def list_joined_rooms(conn, provider) do
    case GenMqtt.call(conn, @adapter_topic, "list_joined_rooms", %{provider: provider}, :infinity) do
      nil ->
        nil
      rooms ->
        Enum.map(rooms, &Room.from_map/1)
    end
  end


  def join(provider, room) when is_binary(room) do
    GenMqtt.with_connection(&(join(&1, provider, room)))
  end
  def join(conn, provider, room) when is_binary(room) do
    GenMqtt.call(conn, @adapter_topic, "join", %{provider: provider, room: room}, :infinity)
  end

  def leave(provider, room) when is_binary(room) do
    GenMqtt.with_connection(&(leave(&1, provider, room)))
  end
  def leave(conn, provider, room) when is_binary(room) do
    GenMqtt.call(conn, @adapter_topic, "leave", %{provider: provider, room: room}, :infinity)
  end


  def list_providers() do
    GenMqtt.with_connection(&(list_providers(&1)))
  end
  def list_providers(conn) do
    GenMqtt.call(conn, @adapter_topic, "list_providers", %{}, :infinity)
  end

  def is_chat_provider?(name) do
    is_chat_provider?(nil, name)
  end
  def is_chat_provider?(_conn, name) do
    name != "http"
  end

  def send(provider, target, message) do
    GenMqtt.with_connection(&(send(&1, provider, target, message)))
  end
  def send(conn, provider, target, message) do
    case prepare_target(target) do
      {:ok, target} ->
        GenMqtt.cast(conn, @adapter_topic, "send", %{provider: provider, target: target, message: message})
      error ->
        Logger.error("#{inspect error}")
        error
    end
  end


  ##########
  # Internals start here
  ##########

  def init(conn, _) do
    Logger.info("Starting")
    case Application.fetch_env(:cog, __MODULE__) do
      :error ->
        {:stop, :missing_chat_adapter_config}
      {:ok, config} ->
        case Keyword.get(config, :providers) do
          nil ->
            Logger.error("Chat provider not specified. You must specify one of 'COG_SLACK_ENABLED' or 'COG_HIPCHAT_ENABLED' env variables")
            {:stop, :missing_chat_providers}
          providers ->
            # TODO: validate that these providers actually implement
            # the proper behavior
            finish_initialization(conn, providers)
        end
    end
  end

  # RPC calls

  def handle_call(_conn, @adapter_topic, _sender, "lookup_room", %{"provider" => provider, "id" => id}, state) do
    {:reply, maybe_cache(with_provider(provider, state, :lookup_room, [id: id]), {provider, :room, id}, state), state}
  end
  def handle_call(_conn, @adapter_topic, _sender, "lookup_room", %{"provider" => provider, "name" => name}, state) do
    {:reply, maybe_cache(with_provider(provider, state, :lookup_room, [name: name]), {provider, :room, name}, state), state}
  end
  def handle_call(_conn, @adapter_topic, _sender, "lookup_user", %{"provider" => provider,
                                                                   "handle" => handle}, state) do
    {:reply, maybe_cache(with_provider(provider, state, :lookup_user, [handle]), {provider, :user, handle}, state), state}
  end
  def handle_call(_conn, @adapter_topic, _sender, "list_joined_rooms", %{"provider" => provider}, state) do
    {:reply, with_provider(provider, state, :list_joined_rooms, []), state}
  end
  def handle_call(_conn, @adapter_topic, _sender, "join", %{"provider" => provider,
                                                            "room" => room}, state) do
    {:reply, with_provider(provider, state, :join, [room]), state}
  end
  def handle_call(_conn, @adapter_topic, _sender, "leave", %{"provider" => provider,
                                                             "room" => room}, state) do
    {:reply, with_provider(provider, state, :leave, [room]), state}
  end
  def handle_call(_conn, @adapter_topic, _sender, "list_providers", %{}, state) do
    {:reply, {:ok, %{providers: Enum.filter(Map.keys(state.providers), &(is_binary(&1)))}}, state}
  end
  def handle_call(_conn, @adapter_topic, _sender, "is_chat_provider", %{"name" => name}, state) do
    # TODO: EXTRACT THIS!!!
    result =  name != "http"

    {:reply, {:ok, result}, state}
  end
  def handle_call(_conn, @adapter_topic, _sender, "mention_name", %{"provider" => provider, "handle" => handle}, state) do
    {:reply, with_provider(provider, state, :mention_name, [handle]), state}
  end
  def handle_call(_conn, @adapter_topic, _sender, "display_name", %{"provider" => provider}, state) do
    {:reply, with_provider(provider, state, :display_name, []), state}
  end


  # Non-blocking "cast" messages
  def handle_cast(_conn, @adapter_topic, "send",  %{"target" => target,
                                                    "message" => message,
                                                    "provider" => provider}, state) do
    case with_provider(provider, state, :send_message, [target, message]) do
      :ok ->
        :ok
      {:error, :not_implemented} ->
        Logger.error("send_message function not implemented for provider '#{provider}'! No message sent")
      {:error, reason} ->
        Logger.error("Failed to send message to provider #{provider}: #{inspect reason, pretty: true}")
    end
    {:noreply, state}
  end

  defp finish_initialization(conn, providers) do
    Connection.subscribe(conn, @adapter_topic)
    case start_providers(providers, %{}) do
      {:ok, providers} ->
        {:ok, %__MODULE__{providers: providers, cache: get_cache()}}
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
        config = [{:incoming_topic, Ingestor.incoming_topic}|config]
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

  defp with_provider(provider, state, fun, args) when is_atom(fun) and is_list(args) do
    case Map.get(state.providers, provider) do
      nil ->
        {:error, :unknown_provider}
      provider ->
        apply(provider, fun, args)
    end
  end

  defp prepare_target(target) do
    case Cog.Chat.Room.from_map(target) do
      {:ok, room} ->
        {:ok, room.id}
      error ->
        error
    end
  end

 defp fetch_cache_ttl do
   config = Application.get_env(:cog, __MODULE__)
   Keyword.get(config, :cache_ttl, {10, :sec})
 end

 defp get_cache do
   ttl = fetch_cache_ttl
   {:ok, cache} = CacheSup.get_or_create_cache(@cache_name, ttl)
   cache
 end

 defp maybe_cache({:ok, _}=value, key, state) do
   Cache.put(state.cache, key, value)
   value
 end
 defp maybe_cache(value, _key, _state), do: value

end

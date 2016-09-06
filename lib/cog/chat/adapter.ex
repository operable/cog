defmodule Cog.Chat.Adapter do

  require Logger

  use Carrier.Messaging.GenMqtt
  alias Cog.Util.CacheSup
  alias Cog.Util.Cache
  alias Cog.Messages.AdapterRequest
  alias Cog.Chat.Room
  alias Cog.Chat.Message
  alias Cog.Chat.User

  @adapter_topic "bot/chat/adapter"
  @incoming_topic "bot/chat/adapter/incoming"
  @cache_name :cog_chat_adapter_cache

  defstruct [:providers, :cache]

  def start_link() do
    GenMqtt.start_link(__MODULE__, [], name: __MODULE__)
  end

  def mention_name(provider, handle) when is_binary(handle) do
    GenMqtt.call(@adapter_topic , "mention_name", %{provider: provider, handle: handle}, :infinity)
  end

  def display_name(provider) do
    GenMqtt.call(@adapter_topic, "display_name", %{provider: provider}, :infinity)
  end

  def lookup_user(provider, handle) when is_binary(handle) do
    cache = get_cache
    case cache[{provider, :user, handle}] do
      nil ->
        case GenMqtt.call(@adapter_topic, "lookup_user", %{provider: provider, handle: handle}, :infinity) do
          {:ok, user} ->
            User.from_map(user)
          {:error, _}=error ->
            error
        end
      {:ok, value} ->
        User.from_map(value)
    end
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

  def lookup_room(provider, room_identifier) do
    cache = get_cache
    case cache[{provider, :room, room_identifier}] do
      nil ->
        case GenMqtt.call(@adapter_topic , "lookup_room", %{provider: provider, id: room_identifier} , :infinity) do
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
    case GenMqtt.call(@adapter_topic, "list_joined_rooms", %{provider: provider}, :infinity) do
      nil ->
        nil
      {:ok, rooms} ->
        {:ok, Enum.map(rooms, &Room.from_map!/1)}
    end
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
    GenMqtt.call(@adapter_topic, "join", %{provider: provider, room: room}, :infinity)
  end
  def join(conn, provider, room) when is_binary(room) do
    GenMqtt.call(conn, @adapter_topic, "join", %{provider: provider, room: room}, :infinity)
  end

  def leave(provider, room) when is_binary(room) do
    GenMqtt.call(@adapter_topic, "leave", %{provider: provider, room: room}, :infinity)
  end
  def leave(conn, provider, room) when is_binary(room) do
    GenMqtt.call(conn, @adapter_topic, "leave", %{provider: provider, room: room}, :infinity)
  end


  def list_providers() do
    GenMqtt.call(@adapter_topic, "list_providers", %{}, :infinity)
  end
  def list_providers(conn) do
    GenMqtt.call(conn, @adapter_topic, "list_providers", %{}, :infinity)
  end

  def is_chat_provider?(name) do
    {:ok, result} = GenMqtt.call(@adapter_topic, "is_chat_provider", %{name: name}, :infinity)
    result
  end
  def is_chat_provider?(conn, name) do
    {:ok, result} = GenMqtt.call(conn, @adapter_topic, "is_chat_provider", %{name: name}, :infinity)
    result
  end

  def send(provider, target, message) do
    case prepare_target(target) do
      {:ok, target} ->
        GenMqtt.cast(@adapter_topic, "send", %{provider: provider, target: target, message: message})
      error ->
        Logger.error("#{inspect error}")
        error
    end
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
        {:error, :missing_chat_adapter_config}
      {:ok, config} ->
        case Keyword.get(config, :providers) do
          nil ->
            {:error, :missing_chat_providers}
          providers ->
            # TODO: validate that these providers actually implement
            # the proper behavior
            finish_initialization(conn, providers)
        end
    end
  end

  # RPC calls

  def handle_call(_conn, @adapter_topic, _sender, "lookup_room", %{"provider" => provider, "id" => id}, state) do
    {:reply, maybe_cache(with_provider(provider, state, :lookup_room, [id]), {provider, :room, id}, state), state}
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
      {:ok, sent_message} ->
        Logger.info("Sent #{:erlang.size(sent_message)} bytes via provider #{provider}.")
        :ok
      {:error, :not_implemented} ->
        Logger.error("send_message function not implemented for provider '#{provider}'! No message sent")
      {:error, reason} ->
        Logger.error("Failed to send message to provider #{provider}: #{inspect reason, pretty: true}")
    end
    {:noreply, state}
  end
  def handle_cast(_conn, @incoming_topic, "event", event, state) do
    Logger.debug("Received chat event: #{inspect event}")
    {:noreply, state}
  end
  def handle_cast(conn, @incoming_topic, "message", message, state) do
    state = case Message.from_map(message) do
              {:ok, message} ->
                case is_pipeline?(message) do
                  {true, text} ->
                    if message.edited == true do
                      mention_name = with_provider(message.provider, state, :mention_name, [message.user.handle])
                      send(conn, message.provider, message.room, "#{mention_name} Executing edited command '#{text}'")
                    end
                    request = %AdapterRequest{text: text, sender: message.user, room: message.room, reply: "", id: message.id,
                                              adapter: message.provider, initial_context: message.initial_context || %{}}
                    Connection.publish(conn, request, routed_by: "/bot/commands")
                    state
                  false ->
                    state
                end
              _error ->
                Logger.error("Ignoring invalid chat message: #{inspect message, pretty: true}")
                state
            end
    {:noreply, state}
  end

  defp finish_initialization(conn, providers) do
    Connection.subscribe(conn, @adapter_topic)
    Connection.subscribe(conn, @incoming_topic)
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

  defp with_provider(provider, state, fun, args) when is_atom(fun) and is_list(args) do
    case Map.get(state.providers, provider) do
      nil ->
        {:error, :unknown_provider}
      provider ->
        apply(provider, fun, args)
    end
  end

  defp is_pipeline?(message) do
    # The notion of "bot name" only really makes sense in the context
    # of chat providers, where we can use that to determine whether or
    # not a message is being addressed to the bot. For other providers
    # (lookin' at you, Http.Provider), this makes no sense, because all
    # messages are directed to the bot, by definition.
    if message.room.is_dm == true do
      {true, message.text}
    else
      case parse_spoken_command(message.text) do
        nil ->
          case parse_mention(message.text, message.bot_name) do
            nil ->
              false
            updated ->
              {true, updated}
          end
        updated ->
          {true, updated}
      end
    end
  end

  defp parse_spoken_command(text) do
    case Application.get_env(:cog, :enable_spoken_commands, true) do
      false ->
        nil
      true ->
        command_prefix = Application.get_env(:cog, :command_prefix, "!")
        updated = Regex.replace(~r/^#{Regex.escape(command_prefix)}/, text, "")
        if updated != text do
          updated
        else
          nil
        end
    end
  end

 defp parse_mention(_text, nil), do: nil
 defp parse_mention(text, bot_name) do
   updated = Regex.replace(~r/^#{Regex.escape(bot_name)}/, text, "")
   if updated != text do
      Regex.replace(~r/^:/, updated, "")
      |> String.trim
    else
      nil
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

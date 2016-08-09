defmodule Cog.Chat.Adapter do

  require Logger

  use Carrier.Messaging.GenMqtt
  alias Cog.Messages.AdapterRequest
  alias Cog.Chat.Room

  @adapter_topic "bot/chat/adapter"
  @incoming_topic "bot/chat/adapter/incoming"

  defstruct [:providers, :counter]

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
    GenMqtt.call(@adapter_topic, "lookup_user", %{provider: provider, handle: handle}, :infinity)
  end
  def lookup_user(conn, provider, handle) when is_binary(handle) do
    GenMqtt.call(conn, @adapter_topic, "lookup_user", %{provider: provider, handle: handle}, :infinity)
  end

  def lookup_room(provider, room_name) do
    case list_joined_rooms(provider) do
      {:ok, rooms} ->
        Enum.reduce_while(rooms, nil,
          fn(room, acc) ->
            if room["name"] == room_name do
              {:halt, Room.from_map(room)}
            else
              {:cont, acc}
            end end)
      error ->
        error
    end
  end

  def list_joined_rooms(provider) do
    case GenMqtt.call(@adapter_topic, "list_joined_rooms", %{provider: provider}, :infinity) do
      nil ->
        nil
      rooms ->
        Enum.map(rooms, &Room.from_map/1)
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
    GenMqtt.call(@adapter_topic, "is_chat_provider", %{name: name}, :infinity)
  end
  def is_chat_provider(conn, name) do
    GenMqtt.call(conn, @adapter_topic, "is_chat_provider", %{name: name}, :infinity)
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
  def handle_call(_conn, @adapter_topic, _sender, "lookup_user", %{"provider" => provider,
                                                                   "handle" => handle}, state) do
    {:reply, with_provider(provider, state, :lookup_user, [handle]), state}
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
    result = Map.put(%{}, name, name != "http")
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
    with_provider(provider, state, :send_message, [target, message])
    Logger.info("Sent #{:erlang.size(message)} bytes via provider #{provider}.")
    {:noreply, state}
  end
  def handle_cast(_conn, @incoming_topic, "event", event, state) do
    Logger.debug("Received chat event: #{inspect event}")
    {:noreply, state}
  end
  def handle_cast(conn, @incoming_topic, "message", %{"room" => room, "user" => user, "text" => text, "provider" => provider,
                                                      "bot_name" => bot_name}, state) do
    state = case is_pipeline?(text, bot_name, room) do
              {true, text} ->
                {id, state} = message_id(state)
                request = %AdapterRequest{text: text, sender: user, room: room, reply: "", id: id,
                                          adapter: provider, initial_context: %{}}
                Connection.publish(conn, request, routed_by: "/bot/commands")
                state
              false ->
                state
            end
    {:noreply, state}
  end

  defp message_id(%__MODULE__{counter: counter}=state) do
    {mega, secs, _} = :os.timestamp()
    id = :erlang.iolist_to_binary(:io_lib.format('~p~p.~7..0B', [mega, secs, counter]))
    counter = if counter == 9999999 do
      1
    else
      counter + 1
    end
    {id, %{state | counter: counter}}
  end

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
        {:ok, %__MODULE__{providers: providers, counter: 1}}
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
  if Mix.env == :test do
  defp resolve_provider_name(:test), do: {:ok, Cog.Chat.TestProvider}
  end
  defp resolve_provider_name(name), do: {:error, {:unknown_chat_provider, name}}

  defp with_provider(provider, state, fun, args) when is_atom(fun) and is_list(args) do
    case Map.get(state.providers, provider) do
      nil ->
        {:error, :unknown_provider}
      provider ->
        apply(provider, fun, args)
    end
  end

  defp is_pipeline?(text, bot_name, room) do
    if room["name"] == "direct" do
      {true, text}
    else
      case parse_spoken_command(text) do
        nil ->
          case parse_mention(text, bot_name) do
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

  defp parse_mention(text, bot_name) do
    updated = Regex.replace(~r/^#{Regex.escape(bot_name)}/, text, "")
    if updated != text do
      Regex.replace(~r/^:/, updated, "")
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
end

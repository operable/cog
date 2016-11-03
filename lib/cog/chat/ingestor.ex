defmodule Cog.Chat.Ingestor do

  use Carrier.Messaging.GenMqtt

  alias Cog.Messages.AdapterRequest
  alias Cog.Command.Pipeline.Initializer, as: PipelineInitializer
  alias Cog.Chat.Message

  @incoming_topic "bot/chat/adapter/incoming"

  def incoming_topic(), do: @incoming_topic

  def start_link() do
    GenMqtt.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(conn, _) do
    Connection.subscribe(conn, @incoming_topic)
    {:ok, []}
  end

  def handle_cast(_conn, @incoming_topic, "event", event, state) do
    Logger.debug("Received chat event: #{inspect event}")
    {:noreply, state}
  end
  def handle_cast(_conn, @incoming_topic, "message", message, state) do
    state = case Message.from_map(message) do
              {:ok, message} ->
                Logger.debug("#{AdapterRequest.age(message)} ms")
                case is_pipeline?(message) do
                  {true, text} ->
                    request = %AdapterRequest{text: text, sender: message.user, room: message.room, reply: "", id: message.id,
                                              timestamp: message.timestamp,
                                              adapter: message.provider, initial_context: message.initial_context || %{}}
                    PipelineInitializer.pipeline(request)
                    state
                  false ->
                    state
                end
              error ->
                Logger.error("Error decoding chat message: #{inspect error}   #{inspect message, pretty: true}")
                state
            end
    {:noreply, state}
  end

  def handle_admin({:chat_event, event}, state) do
    Logger.debug("Received chat event: #{inspect event}")
    {:noreply, state}
  end
  def handle_admin({:chat_message, message}, state) do
    Logger.debug("#{AdapterRequest.age(message)} ms")
    state = case is_pipeline?(message) do
              {true, text} ->
                request = %AdapterRequest{text: text, sender: message.user, room: message.room, reply: "", id: message.id,
                                          timestamp: message.timestamp,
                                          adapter: message.provider, initial_context: message.initial_context || %{}}
                PipelineInitializer.pipeline(request)
                state
              false ->
                state
            end
    {:noreply, state}
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
   updated = Regex.replace(~r/^#{Regex.escape(bot_name)}/i, text, "")
   if updated != text do
      Regex.replace(~r/^:/, updated, "")
      |> String.trim
   else
     nil
   end
 end

end

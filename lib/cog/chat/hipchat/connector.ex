defmodule Cog.Chat.HipChat.Connector do

  require Logger

  use GenServer

  alias Cog.Chat.HipChat.Provider
  alias Cog.Chat.HipChat.Util
  alias Romeo.Connection
  alias Romeo.Roster
  alias Romeo.Stanza


  @provider_name "hipchat"
  @xmpp_timeout 5000
  @roster_refresh_interval 5000
  @heartbeat_interval 30000

  defstruct [:provider, :xmpp_conn, :hipchat_org, :me, :mention_name, :roster, :last_roster_update, :rooms, :fatal_error]

  def start_link(host, user, password, nickname, use_ssl) do
    opts = [jid: user,
            password: password,
            host: host,
            mention_name: nickname,
            require_tls: use_ssl]
    GenServer.start_link(__MODULE__, [opts, self()], name: __MODULE__)
  end

  def init([opts, provider]) do
    [user_name|_] = String.split(Keyword.fetch!(opts, :jid), "@", parts: 2)
    [hipchat_org|_] = String.split(user_name, "_", parts: 2)
    case Connection.start_link(opts) do
      {:ok, conn} ->
        state = %__MODULE__{xmpp_conn: conn, hipchat_org: hipchat_org, rooms: %{},
                            me: Keyword.fetch!(opts, :jid), provider: provider, last_roster_update: 0,
                            mention_name: Keyword.fetch!(opts, :mention_name)}
        case Connection.send(conn, Stanza.presence) do
          :ok ->
            Logger.info("Successfully connected to HipChat organization #{hipchat_org} as '#{state.mention_name}'")
            {:ok, state}
          error ->
            error
        end
      error ->
        error
    end
  end

  def handle_call({:lookup_user, handle}, _from, state) do
    {result, state} = lookup_user(handle, state)
    case result do
      {:ok, _} ->
        {:reply, result, state}
      _ ->
        {:reply, {:error, :lookup_failed}, state}
    end
  end
  def handle_call({:lookup_room, name}, _from, state) do
    {:reply, {:ok, Map.get(state.rooms, name)}, state}
  end
  def handle_call(:list_joined_rooms, _from, state) do
    {:reply, {:ok, Map.values(state.rooms)}, state}
  end
  def handle_call({:send_message, target, message}, _from, state) do
    type = case Map.get(state.rooms, target) do
             nil ->
               "chat"
             _ ->
               "groupchat"
           end
    message = Enum.map(message, fn(%{"name" => "text", "text" => text}) -> text
                                  (%{"name" => "newline"}) -> "\n" end) |> Enum.join("")
    Connection.send(state.xmpp_conn, %Stanza.Message{to: target, type: type, body: message})
    {:reply, :ok, state}
  end


  # Should only happen when we connect
  def handle_info(:connection_ready, state) do
    :timer.send_interval(@heartbeat_interval, :heartbeat)
    case rebuild_roster(state) do
      {:ok, state} ->
        {:noreply, state}
      _error ->
        {:noreply, state}
    end
  end
  # Send heartbeat
  def handle_info(:heartbeat, state) do
    case Connection.send(state.xmpp_conn, Stanza.chat(state.me, "//hb\\")) do
      :ok ->
        :ok
      error ->
        Logger.error("Failed to send heartbeat message to HipChat: #{inspect error}")
    end
    {:noreply, state}
  end
  def handle_info({:stanza, %Stanza.Presence{}=presence}, state) do
    {:ok, state} = handle_presence(state, presence)
    {:noreply, state}
  end
  def handle_info({:stanza, %Stanza.Message{}=message}, state) do
    state = case Util.classify_message(message) do
              {:invite, room_name} ->
                Logger.info("Received an invite to MUC room '#{room_name}'")
                muc_name = "#{state.hipchat_org}_#{room_name}@conf.hipchat.com"
                case Connection.send(state.xmpp_conn, Stanza.join(muc_name, state.mention_name)) do
                  :ok ->
                    Logger.info("Successfully joined MUC room '#{room_name}'")
                  error ->
                    Logger.error("Failed to join MUC room '#{room_name}': #{inspect error}")
                end
                state
              {:groupchat, room_jid, sender, body} ->
                handle_groupchat(room_jid, sender, body, state)
              {:dm, sender, body} ->
                handle_dm(sender, body, state)
              :ignore ->
                state
            end
    {:noreply, state}
  end
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # Error states
  def pending_error(:timeout, state) do
    Logger.error("Error handling HipChat message: #{inspect state.fatal_error}")
    {:stop, :shutdown, state}
  end

  def terminate(_, _, _), do: :ok

  defp handle_presence(state, presence) do
    case lookup_user(state, presence.from.user) do
      {{:ok, nil}, state} ->
        {:ok, state}
      {{:ok, user}, state} ->
        GenServer.cast(Provider, build_event(user, presence))
        {:ok, state}
      _ ->
        {:ok, state}
    end
  end

  defp build_event(user, %Stanza.Presence{}=presence) do
    {:chat_event, %{"presence" => presence_type(presence.show), "provider" => @provider_name, "type" => "presence_change",
                    "user" => user}}
  end

  defp presence_type("xa"), do: "inactive"
  defp presence_type("away"), do: "inactive"
  defp presence_type("chat"), do: "active"
  defp presence_type(""), do: "active"

  defp room_from_jid(room_jid, state) do
    case Map.get(state.rooms, room_jid) do
      nil ->
        id = "#{:erlang.system_time()}"
        xml = [{:xmlel, "query", [{"xmlns", "http://jabber.org/protocol/disco#info"}], []}]
        message = %Stanza.IQ{to: room_jid, type: "get", id: id, xml: xml}
        Connection.send(state.xmpp_conn, message)
        receive do
          {:stanza, %Stanza.IQ{id: ^id}=result} ->
            {:xmlel, "iq", _, [{:xmlel, "query", _, [{:xmlel, "identity", attrs, _}|_]}|_]} = result.xml
            room_name = :proplists.get_value("name", attrs, nil)
            room = %Cog.Chat.Room{id: room_jid, name: room_name, provider: @provider_name, is_dm: false}
            {room, %{state | rooms: Map.put(state.rooms, room_jid, room)}}
          {:stanza, %Stanza.IQ{id: ^id, type: "error"}=error} ->
            Logger.error("Failed to retrieve room information for JID #{room_jid}: #{inspect error}")
            nil
        after @xmpp_timeout ->
            Logger.error("Room information request for JID #{room_jid} timed out")
            nil
        end
      room_name ->
        {room_name, state}
    end
  end

  defp lookup_user(state, name) do
    case Map.get(state.roster, name) do
      nil ->
        case rebuild_roster(state) do
          {:ok, state} ->
            {{:ok, Map.get(state.roster, name)}, state}
          _error ->
            {{:error, :lookup_failed}, state}
        end
      user ->
        {{:ok, user}, state}
    end
  end


  defp handle_groupchat(room_jid, sender, body, state) do
    case room_from_jid(room_jid, state) do
      nil ->
        state
      {room, state} ->
        case Map.get(state.roster, sender) do
          nil ->
            Logger.debug("Roster miss for #{inspect sender}")
            state
          user ->
            GenServer.cast(state.provider, {:chat_message, %Cog.Chat.Message{id: Cog.Events.Util.unique_id,
                                                                             room: room, user: user, text: body, provider: @provider_name,
                                                                             bot_name: "@#{state.mention_name}", edited: false}})
            state
        end
    end
  end

  defp handle_dm(sender, body, state) do
    case lookup_user(state, sender) do
      {{:ok, nil}, state} ->
        state
      {{:ok, user}, state} ->
        room = %Cog.Chat.Room{id: sender,
                              is_dm: true,
                              name: "direct",
                              provider: @provider_name}
        GenServer.cast(state.provider, {:chat_message, %Cog.Chat.Message{id: Cog.Events.Util.unique_id,
                                                                         room: room, user: user, text: body, provider: @provider_name,
                                                                         bot_name: "@#{state.mention_name}", edited: false}})
        state
    end
  end

  defp rebuild_roster(state) do
    ri = System.system_time() - state.last_roster_update
    if ri > @roster_refresh_interval do
      try do
        roster = Enum.reduce(Roster.items(state.xmpp_conn), %{},
          fn(item, roster) ->
            entry = Util.user_from_roster(item, @provider_name)
            roster = if entry.handle != "" do
              Map.put(roster, entry.handle, entry)
            else
              roster
            end
            roster
            |> Map.put("#{entry.first_name} #{entry.last_name}", entry)
            |> Map.put(entry.id, entry)
          end)
        {:ok, %{state | roster: roster, last_roster_update: System.system_time()}}
      catch
        e ->
        Logger.error("Refreshing HipChat roster failed: #{inspect e}")
        {:error, :roster_failed}
      end
    else
      {:ok, state}
    end
  end

end

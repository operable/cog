defmodule Cog.Chat.HipChat.Connector do

  require Logger

  use GenServer

  alias Cog.Chat.HipChat.Users
  alias Cog.Chat.HipChat.Provider
  alias Cog.Chat.HipChat.Rooms
  alias Cog.Chat.HipChat.TemplateProcessor
  alias Cog.Chat.HipChat.Util
  alias Cog.Repository.ChatProviders
  alias Romeo.Connection
  alias Romeo.Stanza


  @provider_name "hipchat"
  @xmpp_timeout 5000
  @room_refresh_interval 5000
  @heartbeat_interval 30000
  @hipchat_api_root "https://api.hipchat.com/v2"

  defstruct [:provider, :xmpp_conn, :hipchat_org, :api_token, :me, :mention_name, :users, :rooms]

  def start_link(host, user, password, nickname, use_ssl, token) do
    opts = [jid: user,
            password: password,
            host: host,
            mention_name: nickname,
            require_tls: use_ssl,
            api_token: token]
    GenServer.start_link(__MODULE__, [opts, self()], name: __MODULE__)
  end

  def init([opts, provider]) do
    [user_name|_] = String.split(Keyword.fetch!(opts, :jid), "@", parts: 2)
    [hipchat_org|_] = String.split(user_name, "_", parts: 2)
    api_token = Keyword.fetch!(opts, :api_token)
    case Connection.start_link(opts) do
      {:ok, conn} ->
        state = %__MODULE__{xmpp_conn: conn, hipchat_org: hipchat_org, rooms: %{}, users: %Users{},
                            rooms: Rooms.new(api_token), me: Keyword.fetch!(opts, :jid), provider: provider,
                            api_token: api_token, mention_name: Keyword.fetch!(opts, :mention_name)}
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
    {result, state} = lookup_user(state, handle)
    case result do
      {:ok, _} ->
        {:reply, result, state}
      _ ->
        {:reply, {:error, :lookup_failed}, state}
    end
  end
  def handle_call({:lookup_room_jid, room_jid}, _from, state) do
    {result, rooms} = Rooms.lookup(state.rooms, state.xmpp_conn, jid: room_jid)
    {:reply, {:ok, result}, %{state | rooms: rooms}}
  end
  def handle_call({:lookup_room_name, room_name}, _from, state) do
    {result, rooms} = Rooms.lookup(state.rooms, state.xmpp_conn, name: room_name)
    {:reply, {:ok, result}, %{state | rooms: rooms}}
  end
  def handle_call(:list_joined_rooms, _from, state) do
    {:reply, {:ok, Rooms.all(state.rooms)}, state}
  end
  def handle_call({:send_message, target, message}, _from, state) do
    message = TemplateProcessor.render(message)
    case Users.quick_lookup(state.users, target) do
      nil ->
        case Rooms.quick_lookup(state.rooms, target) do
          nil ->
            Logger.warn("Unknown message target '#{target}'. Message NOT sent.")
            {:reply, :ok, state}
          room ->
            send_room_message(room, message, state)
        end
      user ->
        send_user_message(user, message, state)
    end
  end

  # Should only happen when we connect
  def handle_info(:connection_ready, state) do
    case rejoin_rooms(state) do
      {:ok, state} ->
        :timer.send_interval(@heartbeat_interval, :heartbeat)
        {:noreply, state}
      _error ->
        {:stop, :init_error, state}
    end
  end
  # Send heartbeat
  def handle_info(:heartbeat, state) do
    case Connection.send(state.xmpp_conn, Stanza.chat(state.me, " ")) do
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
                join_room(room_name, state, save: true)
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
    case Users.lookup(state.users, name, state.xmpp_conn) do
      {:error, _} ->
        {{:error, :lookup_failed}, state}
      {result, users} ->
        {{:ok, result}, %{state | users: users}}
    end
  end

  defp handle_groupchat(room_jid, sender, body, state) do
    case room_from_jid(room_jid, state) do
      nil ->
        state
      {room, state} ->
        case lookup_user(state, sender) do
          {{:ok, nil}, state} ->
            Logger.debug("Roster miss for #{inspect sender}")
            state
          {{:ok, user}, state} ->
            GenServer.cast(state.provider, {:chat_message, %Cog.Chat.Message{id: Cog.Events.Util.unique_id,
                                                                             room: room, user: user, text: body, provider: @provider_name,
                                                                             bot_name: "@#{state.mention_name}", edited: false}})
            state
          _error ->
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

  defp send_room_message(room, message, state) do
    body = Poison.encode!(%{message_format: "html",
                            color: "gray",
                            notify: true,
                            message: message})
    url = Enum.join([@hipchat_api_root, "room", room.id, "notification"], "/") <> "?token=#{state.api_token}"
    response = HTTPotion.post(url, headers: ["Content-Type": "application/json",
                                             "Accepts": "application/json",
                                             "Authorization": "Bearer #{state.api_token}"],
      body: body)
    unless HTTPotion.Response.success?(response) do
      Logger.error("Sending message to room '#{room.name}' failed: #{response.body}")
    end
    {:reply, :ok, state}
  end

  defp send_user_message(user, message, state) do
    body = Poison.encode!(%{notify: true,
                            message_format: "html",
                            message: message})
    url = Enum.join([@hipchat_api_root, "user", user.email, "message"], "/")
    IO.puts "#{url}"
    response = HTTPotion.post(url, headers: ["Content-Type": "application/json",
                                             "Accepts": "application/json",
                                             "Authorization": "Bearer #{state.api_token}"],
      body: body)
    unless HTTPotion.Response.success?(response) do
      Logger.error("Sending message to user '#{user.handle}' failed: #{response.body}")
    end
    {:reply, :ok, state}
  end

  defp rejoin_rooms(state) do
    case ChatProviders.get_provider_state(@provider_name) do
      nil ->
        {:ok, state}
      pstate ->
        IO.inspect pstate
        case Enum.reduce_while(Map.get(pstate, "rooms", []), :ok,
              fn(room_name, acc) ->
                case join_room(room_name, state) do
                  :ok ->
                    {:cont, acc}
                  :error ->
                    {:halt, :error}
                end end) do
          :ok ->
            {:ok, state}
          _ ->
            :error
        end
    end
  end

  defp join_room(room_name, state, opts \\ [save: false]) do
    muc_name = "#{state.hipchat_org}_#{room_name}@conf.hipchat.com"
    case Connection.send(state.xmpp_conn, Stanza.join(muc_name, state.mention_name)) do
      :ok ->
        Logger.info("Successfully joined MUC room '#{room_name}'")
        unless Keyword.get(opts, :save, false) == false do
          pstate = ChatProviders.get_provider_state(@provider_name)
          updated = Map.update(pstate, "rooms", [room_name], &([room_name|&1]))
          case ChatProviders.set_provider_state(@provider_name, updated) do
            {:ok, _} ->
              :ok
            error ->
              Logger.error("Failed to save joined room to persistent state: #{inspect error}")
              :ok
          end
        end
        :ok
      error ->
        Logger.error("Failed to join MUC room '#{room_name}': #{inspect error}")
        :error
    end
  end

end

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

  defstruct [:provider, :xmpp_conn, :hipchat_org, :api_token, :api_host, :conf_host, :me, :mention_name, :users, :rooms]

  def start_link(config) do
    GenServer.start_link(__MODULE__, [config, self()], name: __MODULE__)
  end

  def init([config, provider]) do
    api_host = Keyword.fetch!(config, :api_host)
    chat_host = Keyword.fetch!(config, :chat_host)
    conf_host = Keyword.fetch!(config, :conf_host)
    api_token = Keyword.fetch!(config, :api_token)
    jabber_id = Keyword.fetch!(config, :jabber_id)
    jabber_password = Keyword.fetch!(config, :jabber_password)
    nickname = Keyword.fetch!(config, :nickname)
    use_ssl = Keyword.get(config, :ssl, true)
    [user_name|_] = String.split(jabber_id, "@", parts: 2)
    [hipchat_org|_] = String.split(user_name, "_", parts: 2)
    opts = [host: chat_host,
            jid: jabber_id,
            password: jabber_password,
            require_tls: use_ssl]
    case Connection.start_link(opts) do
      {:ok, conn} ->
        state = %__MODULE__{xmpp_conn: conn, hipchat_org: hipchat_org, users: %Users{},
                            rooms: Rooms.new(api_token), me: Keyword.fetch!(opts, :jid), provider: provider,
                            api_token: api_token, mention_name: nickname, api_host: api_host, conf_host: conf_host}
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

  def handle_call({:lookup_user_jid, jid}, _from, state) do
    {result, state} = lookup_user(state, jid: jid)
    case result do
      {:ok, nil} ->
        {:reply, {:error, :not_found}, state}
      {:ok, user} ->
        {:reply, {:ok, user}, state}
      _ ->
        {:reply, {:error, :lookup_failed}, state}
    end
  end
  def handle_call({:lookup_user_handle, handle}, _from, state) do
    {result, state} = lookup_user(state, handle: handle)
    case result do
      {:ok, nil} ->
        {:reply, {:error, :not_found}, state}
      {:ok, user} ->
        {:reply, {:ok, user}, state}
      _ ->
        {:reply, {:error, :lookup_failed}, state}
    end
  end
  def handle_call({:lookup_room_jid, room_jid}, _from, state) do
    {result, state} = lookup_room(state, jid: room_jid)
    case result do
      {:ok, nil} ->
        # This might be an attempt to resolve the 'me' redirect target
        # so let's try resolving the room jid as a user
        {result, state} = lookup_user(state, jid: room_jid)
        case result do
          {:ok, nil} ->
            {:reply, {:error, :not_found}, state}
          # We found the user so let's construct a DM "room"
          # usable as a redirect
          {:ok, user} ->
            room = %Cog.Chat.Room{id: user.id,
                                  is_dm: true,
                                  name: "direct",
                                  provider: @provider_name}
            {:reply, {:ok, room}, state}
          _ ->
            {:reply, {:error, :lookup_failed}, state}
        end
      {:ok, room} ->
        {:reply, {:ok, room}, state}
      _ ->
        {:reply, {:error, :lookup_failed}, state}
    end
  end
  def handle_call({:lookup_room_name, room_name}, _from, state) do
    {result, state} = lookup_room(state, name: room_name)
    case result do
      {:ok, nil} ->
        {:reply, {:error, :not_found}, state}
      {:ok, room} ->
        {:reply, {:ok, room}, state}
      _ ->
        {:reply, {:error, :lookup_failed}, state}
    end
  end
  def handle_call(:list_joined_rooms, _from, state) do
    {:reply, {:ok, Rooms.all(state.rooms)}, state}
  end
  def handle_call({:send_message, target, message}, _from, state) do
    send_output(state, target, TemplateProcessor.render(message))
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
                join_room(room_name, state)
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
    case lookup_user(state, handle: presence.from.user) do
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

  defp lookup_user(state, try_both: name_or_jid) do
    case lookup_user(state, jid: name_or_jid) do
      {{:ok, nil}, state} ->
        lookup_user(state, name: name_or_jid)
      results ->
        results
    end
  end
  defp lookup_user(state, opts) do
    case Users.lookup(state.users, state.xmpp_conn, opts) do
      {:error, _} ->
        {{:error, :lookup_failed}, state}
      {result, users} ->
        {{:ok, result}, %{state | users: users}}
    end
  end

  defp lookup_room(state, opts) do
    case Rooms.lookup(state.rooms, state.xmpp_conn, opts) do
      {:error, _} ->
        {{:error, :lookup_failed}, state}
      {result, rooms} ->
        {{:ok, result}, %{state | rooms: rooms}}
    end
  end

  defp handle_groupchat(room_jid, sender, body, state) do
    case lookup_room(state, jid: room_jid) do
      {{:ok, nil}, state} ->
        state
      {{:ok, room}, state} ->
        case lookup_user(state, jid: sender) do
          {{:ok, nil}, state} ->
            Logger.debug("Roster miss for #{inspect sender}")
            state
          {{:ok, user}, state} ->
            GenServer.cast(state.provider, {:chat_message, %Cog.Chat.Message{id: Cog.Events.Util.unique_id,
                                                                             room: room, user: user, text: body, provider: @provider_name,
                                                                             bot_name: "@#{state.mention_name}", edited: false}})
            state
          error ->
            Logger.error("Failed to lookup sender of groupchat message: #{inspect error}")
            state
        end
      error ->
        Logger.error("Failed to lookup room for groupchat message: #{inspect error}")
    end
  end

  defp handle_dm(sender, body, state) do
    case lookup_user(state, jid: sender) do
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

  defp send_output(state, target, output) do
    case lookup_user(state, try_both: target) do
      {{:ok, nil}, state} ->
        case lookup_room(state, name: target) do
          {{:ok, nil}, state} ->
            Logger.warn("Unknown message target '#{target}'. Message NOT sent.")
            {:reply, :ok, state}
          {{:ok, room}, state} ->
            send_room_message(room, output, state)
          error ->
            Logger.error("Failed to lookup target '#{target}' as room. Message NOT sent: #{inspect error}")
        end
      {{:ok, user}, state} ->
        send_user_message(user, output, state)
      error ->
        Logger.error("Failed to lookup target '#{target}' as user. Message NOT sent: #{inspect error}")
    end
  end

  defp prepare_message(text) when is_binary(text) do
    Poison.encode!(%{message_format: "html",
                     color: "gray",
                     notify: true,
                     message: text})
  end

  defp send_room_message(room, message, state) do
    body = prepare_message(message)
    url = Enum.join([api_root(state), "room", room.secondary_id, "notification"], "/") <> "?token=#{state.api_token}"
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
    body = prepare_message(message)
    url = Enum.join([api_root(state), "user", user.email, "message"], "/")
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
        rooms = finalize_rooms(Map.get(pstate, "rooms", []), System.get_env("HIPCHAT_ROOMS"))
        unless length(rooms) == 0 do
          Logger.info("Rejoining #{Enum.join(rooms, ", ")}")
        end
        case Enum.reduce(rooms, [],
              fn(room_name, acc) ->
                case join_room(room_name, state) do
                  :ok ->
                    acc
                  :error ->
                    [room_name|acc]
                end end) do
          [] ->
            {:ok, state}
          errors ->
            Logger.error("Failed to rejoin the following rooms: #{Enum.join(errors, ",")}")
            {:ok, state}
        end
    end
  end

  defp finalize_rooms(pstate_rooms, nil), do: pstate_rooms
  defp finalize_rooms(pstate_rooms, envvar_rooms) do
    env_rooms = String.split(envvar_rooms, " ", trim: true)
    Enum.uniq(pstate_rooms ++ env_rooms)
  end

  defp join_room(room_name, state) do
    # If we were given a JID then use it, else build a JID
    # using the hipchat org and conf_host
    muc_name = if String.contains?(room_name, state.conf_host) do
      room_name
    else
      "#{state.hipchat_org}_#{room_name}@#{state.conf_host}"
    end
    case Connection.send(state.xmpp_conn, Stanza.join(muc_name, state.mention_name)) do
      :ok ->
        Logger.info("Successfully joined MUC room '#{room_name}'")
        pstate = ChatProviders.get_provider_state(@provider_name)
        updated = Map.update(pstate, "rooms", [room_name], &(Enum.uniq([room_name|&1])))
        case ChatProviders.set_provider_state(@provider_name, updated) do
          {:ok, _} ->
            :ok
          error ->
            Logger.error("Failed to save joined room to persistent state: #{inspect error}")
            :ok
        end
      error ->
        Logger.error("Failed to join MUC room '#{room_name}': #{inspect error}")
        :error
    end
  end

  defp api_root(state) do
    "https://#{state.api_host}/v2"
  end

end

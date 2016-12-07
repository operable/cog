defmodule Cog.Test.Support.HipChatClient do

  @default_timeout 5000
  @api_root "https://api.hipchat.com/v2"
  @conf_host "conf.hipchat.com"

  use GenServer

  alias Romeo.Connection
  alias Romeo.Stanza
  alias Cog.Chat.HipChat.Util
  alias Cog.Chat.HipChat.Rooms
  alias Cog.Chat.HipChat.Users

  defstruct [:hipchat_org, :mention_name, :conn, :rooms, :users, :waiters]

  # Required for uniform interface between Slack and HipChat
  # test clients
  def new(), do: __MODULE__.start_link()

  def start_link() do
    api_token = get_env!("HIPCHAT_USER_API_TOKEN")
    xmpp_jid = get_env!("HIPCHAT_USER_JABBER_ID")
    xmpp_password = get_env!("HIPCHAT_USER_JABBER_PASSWORD")
    nickname = get_env!("HIPCHAT_USER_NICKNAME")
    GenServer.start_link(__MODULE__, [api_token, xmpp_jid, xmpp_password, nickname])
  end

  def init([api_token, xmpp_jid, xmpp_password, nickname]) do
    opts = [host: "chat.hipchat.com",
            jid: xmpp_jid,
            password: xmpp_password,
            require_tls: true]
    [user_name|_] = String.split(xmpp_jid, "@", parts: 2)
    [hipchat_org|_] = String.split(user_name, "_", parts: 2)
    case Connection.start_link(opts) do
      {:ok, conn} ->
        :ok = Connection.send(conn, Stanza.presence)

        # We join each room and then wait for a response from hipchat before
        # continuing on to the next. We do this to alleviate some intermittent
        # failures we were seeing in tests. Some tests were failing with a
        # "not in room" error. Using this method should help guarantee that we
        # are in the room before sending a message or at least fail earlier
        # with a more useful error message.
        rooms = [
          "#{hipchat_org}_ci_bot_testing@conf.hipchat.com",
          "#{hipchat_org}_ci_bot_redirect_tests@conf.hipchat.com",
          "#{hipchat_org}_private_ci_testing@conf.hipchat.com"
        ]
        Enum.each(rooms, fn(room) ->
          # Send a message to join the room
          :ok = Connection.send(conn, Stanza.join(room, nickname))
          # Wait for a response before continuing
          :ok = wait_for_join(room)
        end)

        {:ok, %__MODULE__{conn: conn, waiters: %{}, rooms: Rooms.new(@api_root, api_token),
                          users: %Users{}, hipchat_org: hipchat_org,
                          mention_name: nickname}}
      error ->
        error
    end
  end

  defp wait_for_join(full) do
    receive do
      {:stanza, %Stanza.Message{body: "", from: %Romeo.JID{full: ^full}}} ->
        :ok
    after
        @default_timeout ->
          raise "Error: Timeout waiting for bot to join room: #{full}"
    end
  end

  def chat_wait!(client, opts) do
    room = Keyword.fetch!(opts, :room)
    message = Keyword.fetch!(opts, :message)
    reply_from = Keyword.fetch!(opts, :reply_from)
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    GenServer.call(client, {:chat_and_wait, room, message, reply_from}, timeout)
  end

  def handle_call({:chat_and_wait, room, message, reply_from}, from, state) do
    {room, rooms} = Rooms.lookup(state.rooms, state.conn, name: room)
    state = send_room_message(room, message, state)
    {:noreply, %{state | rooms: rooms, waiters: Map.update(state.waiters, reply_from, [from],
                    fn(waiters) -> [from|waiters] end)}}
  end

  def handle_info({:stanza, %Stanza.Message{}=message}, state) do
    state = case Util.classify_message(message) do
              {:invite, room_name} ->
                join_room(room_name, state)
                state
              {:groupchat, room_jid, sender, body} ->
                handle_groupchat(room_jid, sender, body, state)
              {:dm, sender_jid, body} ->
                {user, users} = Users.lookup(state.users, state.conn, jid: sender_jid)
                state = %{state | users: users}
                handle_dm(user.mention_name, body, state)
              :ignore ->
                state
            end
    {:noreply, state}
  end
  def handle_info(_ignored, state) do
    {:noreply, state}
  end

  defp handle_dm(sender, body, state) do
    case Map.get(state.waiters, sender) do
      nil ->
        state
      waiters ->
        location = %{type: :im}
        message = %{location: location, text: body}
        Enum.each(waiters, fn(waiter) -> GenServer.reply(waiter, {:ok, message}) end)
        %{state | waiters: Map.delete(state.waiters, sender)}
    end
  end
  defp handle_groupchat(room_jid, sender, body, state) do
    {room, rooms} = Rooms.lookup(state.rooms, state.conn, jid: room_jid)
    state = %{state | rooms: rooms}
    case Map.get(state.waiters, sender) do
      nil ->
        state
      waiters ->
        location = %{type: :channel, name: room.name}
        message = %{text: body, location: location}
        Enum.each(waiters, fn(waiter) -> GenServer.reply(waiter, {:ok, message}) end)
        %{state | waiters: Map.delete(state.waiters, sender)}
    end
  end

  defp get_env!(name) do
    case System.get_env(name) do
      nil ->
        raise RuntimeError, message: "$#{name} not set!"
      value ->
        value
    end
  end

  defp send_room_message(room, message, state) do
    Connection.send(state.conn, Stanza.groupchat(room.id, message))
    state
  end

  defp join_room(room_name, state) do
    # If we were given a JID then use it, else build a JID
    # using the hipchat org and conf_host
    muc_name = if String.contains?(room_name, @conf_host) do
      room_name
    else
      "#{state.hipchat_org}_#{room_name}@#{@conf_host}"
    end
    Connection.send(state.conn, Stanza.join(muc_name, state.mention_name))
  end

end

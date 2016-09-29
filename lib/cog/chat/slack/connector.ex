defmodule Cog.Chat.Slack.Connector do
  require Logger
  use Slack

  alias Cog.Chat.Message
  alias Cog.Chat.Room
  alias Cog.Chat.Slack.Formatter
  alias Cog.Chat.Slack.Provider
  alias Cog.Chat.User

  @provider_name "slack"

  def call(connector, token, type, args \\ %{}) do
    args = Map.put(args, :token, token)
    ref = :erlang.make_ref()
    send(connector, {{ref, self()}, {type, args}})
    receive do
      {^ref, reply} ->
        reply
    after 10000 ->
        {:error, :timeout}
    end
  end

  def handle_connect(state) do
    Logger.info("Connected to Slack with handle '#{state.me.name}'.")
  end

  def handle_message(msg, state) do
    case annotate(msg, state) do
      :ignore ->
        :ok
      msg ->
        GenServer.cast(Provider, msg)
        :ok
    end
  end

  def handle_info({{ref, sender}, {:join, %{token: token, room: room}}}, state) do
    case lookup_room(room, state.channels, by: :name) do
      nil ->
        send(sender, {ref, {:error, :not_found}})
      room ->
        send(sender, {ref, Slack.Web.Channels.join(room["id"], %{token: token})})
    end
    :ok
  end
  def handle_info({{ref, sender}, {:leave, %{token: token, room: room}}}, state) do
    case lookup_room(room, state.channels, by: :name) do
      nil ->
        send(sender, {ref, {:error, :not_found}})
      room ->
        send(sender, {ref, Slack.Web.Channels.leave(room["id"], %{token: token})})
    end
    :ok
  end
  def handle_info({{ref, sender}, {:list_joined_rooms, _}}, state) do
    rooms = state
    |> joined_channels
    |> Enum.map(fn({_, room}) -> make_room(room) end)
    send(sender, {ref, rooms})
    :ok
  end
  def handle_info({{ref, sender}, {:lookup_user, %{handle: handle}}}, state) do
    result = lookup_user(handle, state.users, by: :handle)
    send(sender, {ref, result})
    :ok
  end
  def handle_info({{ref, sender}, {:send_message, %{token: token, target: target}=args}}, _state) do
    message = %{token: token, as_user: true}
    message = case Map.get(args, :message) do
                nil ->
                  message
                text ->
                  text_size = :erlang.size(text)
                  unless text_size < 15000 do
                    Logger.info("WARNING: Large message (#{text_size} bytes) detected. Slack might truncate or drop it entirely.")
                  end
                  Map.put(message, :text, text)
              end
    message = case Map.get(args, :attachments) do
                nil ->
                  message
                attachments ->
                  Map.put(message, :attachments, Poison.encode!(attachments))
              end
    result = Slack.Web.Chat.post_message(target, message)
    send(sender, {ref, result})
    :ok
  end
  def handle_info({{ref, sender}, {:lookup_room, %{id: id, token: token}}}, state) do
    result = case classify_id(id) do
      :user ->
        case open_dm(id, token) do
          {:ok, room} ->
            {:ok, room}
          {:error, error} ->
            Logger.warn("Could not establish an IM with user #{Slack.Lookups.lookup_user_name(id, state)} (Slack ID: #{id}): #{inspect error}")
            {:error, :user_not_found}
        end
      :channel ->
        case lookup_room(id, joined_channels(state), by: :id) do
          %Room{}=room -> {:ok, room}
          _ -> {:error, :not_a_member}
        end
      :error ->
        {:error, :not_found}
    end

    send(sender, {ref, result})
    :ok
  end
  def handle_info({{ref, sender}, {:lookup_room, %{name: name, token: token}}}, state) do
    result = case classify_name(name) do
      :user ->
        case open_dm(Slack.Lookups.lookup_user_id(name, state), token) do
          {:ok, room} ->
            {:ok, room}
          {:error, error} ->
            Logger.warn("Could not establish an IM with user #{name} (Slack ID: #{Slack.Lookups.lookup_user_id(name, state)}): #{inspect error}")
            {:error, :user_not_found}
        end
      :channel ->
        case lookup_room(name, joined_channels(state), by: :name) do
          %Room{}=room -> {:ok, room}
          _ -> {:error, :not_a_member}
        end
      :error ->
        {:error, :not_found}
    end

    send(sender, {ref, result})
    :ok
  end
  def handle_info(message, _state) do
    Logger.warn("Unexpected INFO message received: #{inspect message}")
    :ok
  end

  # Return map of ID => Slack channels for channels the bot is a member
  # of
  #
  # They're not Cog.Chat.Rooms!
  defp joined_channels(state) do
    channels = Map.merge(state.channels, state.groups)

    Enum.filter(channels, fn
      {_, %{is_channel: true, is_member: true, is_archived: false}} ->
        true
      {_, %{is_group: true, members: members, is_archived: false}} ->
        state.me.id in members
      _ ->
        false
    end)
  end

  defp lookup_room(value, rooms, [by: :name]) do
    Enum.reduce_while(rooms, nil, &(room_by_name(value, &1, &2)))
  end
  defp lookup_room(value, rooms, [by: :id]) do
    Enum.reduce_while(rooms, nil, &(room_by_id(value, &1, &2)))
  end

  defp lookup_user(value, users, [by: :id]) do
    Enum.reduce_while(users, nil, &(user_by_id(value, &1, &2)))
  end
  defp lookup_user(value, users, [by: :handle]) do
    Enum.reduce_while(users, nil, &(user_by_name(value, &1, &2)))
  end

  defp lookup_dm(value, dms) do
    Enum.reduce_while(dms, nil, &(dm_by_id(value, &1, &2)))
  end

  defp open_dm(user_id, token) do
    case Slack.Web.Im.open(user_id, %{token: token}) do
      %{"channel" => %{"id" => id}} ->
        {:ok, %Room{id: id,
                    name: "direct",
                    provider: @provider_name,
                    is_dm: true}}
      %{"error" => error} ->
        {:error, error}
    end
  end

  defp room_by_name("#" <> name, {_, room}, acc) do
    if room.name == name do
      {:halt, make_room(%{id: room.id,
                          name: room.name})}
    else
      {:cont, acc}
    end
  end

  defp room_by_id(id, {id, room}, _acc) do
    {:halt, make_room(room)}
  end
  defp room_by_id(_, _, acc), do: {:cont, acc}

  defp user_by_name(name, {_, user}, acc) do
    if user.name == name do
      {:halt, make_user(user)}
    else
      {:cont, acc}
    end
  end

  defp user_by_id(id, {id, user}, _acc) do
    {:halt, make_user(user)}
  end
  defp user_by_id(_, _, acc), do: {:cont, acc}

  defp dm_by_id(id, {id, _im}, _acc) do
    {:halt, %Room{id: id,
                  name: "direct",
                  provider: "slack",
                  is_dm: true}}
  end
  defp dm_by_id(_, _, acc) do
    {:cont, acc}
  end

  defp make_room(room) do
    %Room{id: room.id,
          name: room.name,
          provider: "slack",
          is_dm: false}
  end

  defp make_user(user) do
    # Slack doesn't set is_bot on slackbot messages :(
    if user.is_bot or user.name == "slackbot" do
      %User{id: user.id,
            first_name: user.name,
            last_name: user.name,
            handle: user.name,
            mention_name: user.name,
            provider: "slack"}
    else
      profile = user.profile
      %User{id: user.id,
            first_name: Map.get(profile, :first_name, user.name),
            last_name: Map.get(profile, :last_name, user.name),
            handle: user.name,
            mention_name: user.name,
            email: profile.email,
            provider: "slack"}
    end
  end

  defp annotate(%{type: "message",
                  subtype: "message_changed",
                  channel: channel,
                  message: %{type: "message", user: user}=message}, state) do
    if user == state.me.id do
      :ignore
    else
      # Edited "messages" don't have a channel key, so we'll pull it in
      # from the outer "envelope"
      case annotate_message(Map.put(message, :channel, channel), state) do
        :ignore ->
          :ignore
        {:chat_message, annotated} ->
          {:chat_message, %{annotated | edited: true}}
      end
    end
  end
  defp annotate(%{type: "message", user: user}=message, state) do
    if user == state.me.id do
      :ignore
    else
      annotate_message(message, state)
    end
  end
  defp annotate(%{type: type, user: user, presence: presence}, state) when type in ["presence_change", "manual_presence_change"] do
    if user == state.me.id do
      :ignore
    else
      user = lookup_user(user, state.users, by: :id)
      {:chat_event, %{type: "presence_change", user: user, presence: presence, provider: "slack"}}
    end
  end
  defp annotate(_, _), do: :ignore

  defp annotate_message(%{channel: channel, user: userid, text: text}, state) do
    text = Formatter.unescape(text, state)
    user = lookup_user(userid, state.users, by: :id)

    if user == nil do
      Logger.info("Failed looking up user '#{userid}'.")
      :ignore
    else
      room = case channel_type(channel) do
        :room ->
          lookup_room(channel, state.channels, by: :id)
        :group ->
          lookup_room(channel, state.groups, by: :id)
        :dm ->
          lookup_dm(userid, state.users)
      end

      if room == nil do
        Logger.info("Failed looking up channel '#{channel}'.")
        :ignore
      else
        {:chat_message, %Message{id: Cog.Events.Util.unique_id,
            room: room, user: user, text: text, provider: @provider_name,
            bot_name: "@#{state.me.name}", edited: false}}
      end
    end
  end

  defp channel_type(<<"C", _ :: binary>>),
    do: :room
  defp channel_type(<<"G", _ :: binary>>),
    do: :group
  defp channel_type(<<"D", _ :: binary>>),
    do: :dm

  defp classify_name(<<"@", _::binary>>), do: :user
  defp classify_name(<<"#", _::binary>>), do: :channel
  defp classify_name(other) do
    Logger.warn("Could not classify Slack name `#{other}`")
    :error
  end

  # Strip off any enclosing angle brackets (Slack processes strings
  # like "#channel_name" and "@user_name" to their internal identifiers
  # like "<#C1234567>" and "<@U1234567>".)
  defp classify_id(id),
    do: id |> String.replace(~r/(^<|>$)/, "") |> do_classify_id

  defp do_classify_id(<<"#C", _::binary>>), do: :channel
  defp do_classify_id(<<"C", _::binary>>), do: :channel
  defp do_classify_id(<<"@U", _::binary>>), do: :user
  defp do_classify_id(<<"U", _::binary>>), do: :user
  defp do_classify_id(other) do
    Logger.warn("Could not classify Slack id `#{other}`")
    :error
  end
end

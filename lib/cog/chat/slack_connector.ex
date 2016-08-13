defmodule Cog.Chat.SlackConnector do
  require Logger
  use Slack

  alias Cog.Chat.SlackProvider
  alias Cog.Chat.User
  alias Cog.Chat.Room

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
        GenServer.cast(SlackProvider, msg)
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
  def handle_info({{ref, sender}, {:send_message, %{token: token, target: target,
                                                    message: message}}}, _state) do
    message_size = :erlang.size(message)
    unless message_size < 15000 do
      Logger.info("WARNING: Large message (#{message_size} bytes) detected. Slack might truncate or drop it entirely.")
    end
    result = Slack.Web.Chat.post_message(target, message, %{token: token, as_user: true})
    send(sender, {ref, result})
    :ok
  end
  def handle_info({{ref, sender}, {:lookup_room, %{id: id, token: token}}}, state) do
    # Figure out what an internal Slack identifier actually points to
    # (user, channel, DM, etc).
    result = case classify_id(id) do
               {:user, user_id} ->
                 case Slack.Web.Im.open(user_id, %{token: token}) do
                   %{"channel" => %{"id" => id}} ->
                     {:ok, %Room{id: id,
                                 name: "direct",
                                 provider: "slack",
                                 is_dm: true}}
                   %{"error" => error} ->
                     Logger.warn("Could not establish an IM with user #{Slack.Lookups.lookup_user_name(user_id, state)} (Slack ID: #{user_id}): #{inspect error}")
                     {:error, :user_not_found}
                 end
               {:channel, channel_id} ->
                 case lookup_room(channel_id, joined_channels(state), by: :id) do
                   %Room{}=room ->
                     {:ok, room}
                   _ ->
                     {:error, :not_a_member}
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
    Enum.filter(state.channels,
      fn({_, info}) -> info.is_member == true and info.is_archived == false end)
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

  defp room_by_name(name, {_, room}, acc) do
    if room.name == name do
      {:halt, %{"id" => room.id,
               "name" => room.name}}
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

  defp user_by_id(id, {id, user}, acc) do
    if Map.has_key?(user.profile, :first_name) do
      {:halt, make_user(user)}
    else
      {:cont, acc}
    end
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
    if user.is_bot do
      %User{id: user.id,
            first_name: user.profile.first_name,
            last_name: user.profile.last_name,
            handle: user.name,
            provider: "slack"}
    else
      %User{id: user.id,
            first_name: user.profile.first_name,
            last_name: user.profile.last_name,
            handle: user.name,
            provider: "slack",
            email: user.profile.email}
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

 defp annotate_message(%{channel: << <<"C">>, _::binary >>=channel, user: userid, text: text}, state) do
   user = lookup_user(userid, state.users, by: :id)
   if user == nil do
     Logger.info("Failed looking up user '#{userid}'.")
     :ignore
   else
     room = lookup_room(channel, state.channels, by: :id)
     if room == nil do
       Logger.info("Failed looking up room '#{channel}'.")
       :ignore
     else
       {:chat_message, %{room: room, user: user, type: "message", text: text, provider: "slack", bot_name: "<@#{state.me.id}>"}}
     end
   end
 end
 defp annotate_message(%{channel: << <<"D">>, _::binary >>=channel, user: userid, text: text}, state) do
   user = lookup_user(userid, state.users, by: :id)
   if user == nil do
     Logger.info("Failed looking up user '#{userid}'.")
     :ignore
   else
     room = lookup_dm(channel, state.ims)
     if room == nil do
       Logger.info("Failed looking up direct message session '#{channel}'.")
       :ignore
     else
       {:chat_message, %{room: room, user: user, type: "message", text: text, provider: "slack", bot_name: "@#{state.me.name}"}}
     end
   end
 end

 # Strip off any enclosing angle brackets (Slack processes strings
 # like "#channel_name" and "@user_name" to their internal identifiers
 # like "<#C1234567>" and "<@U1234567>".)
 defp classify_id(id),
   do: id |> String.replace(~r/(^<|>$)/, "") |> do_classify_id

 # TODO: use Slack.Lookups to verify the "C" and "U" cases here, to
 # guard against bare user / room names that start with those letters
 defp do_classify_id(<<"#C", id::binary>>), do: {:channel, "C#{id}"}
 defp do_classify_id(<<"C", id::binary>>), do: {:channel, "C#{id}"}
 defp do_classify_id(<<"@U", id::binary>>), do: {:user, "U#{id}"}
 defp do_classify_id(<<"U", id::binary>>), do: {:user, "U#{id}"}
 defp do_classify_id(other) do
   Logger.warn("Could not classify Slack identifier '#{other}'")
   :error
 end

end

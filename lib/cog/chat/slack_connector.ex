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
    rooms = Enum.filter(state.channels,
      fn({_, info}) -> info.is_member == true and info.is_archived == false end)
    rooms = Enum.map(rooms, fn({_, info}) -> %{"id" => info.id,
                                               "name" => info.name} end)
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
    {:halt, %Room{id: id,
                  name: room.name,
                  provider: "slack",
                  is_dm: false}}
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

  defp make_user(user) do
    chat_user = %User{id: user.id,
                      first_name: user.profile.first_name,
                      last_name: user.profile.last_name,
                      handle: user.name,
                      provider: "slack"}
   if user.is_bot == false do
     %{chat_user | email: user.profile.email}
   else
    chat_user
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

end

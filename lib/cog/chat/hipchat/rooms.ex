defmodule Cog.Chat.HipChat.Rooms do

  require Logger

  alias Romeo.Connection
  alias Romeo.Stanza

  @xmpp_timeout 5000

  defstruct [:api_token, :hipchat_api_root, :rooms]

  def new(api_token) do
    %__MODULE__{api_token: api_token, hipchat_api_root: "https://api.hipchat.com/v2"}
  end

  def quick_lookup(%__MODULE__{}=rooms, name_or_jid) do
    Map.get(rooms.rooms, name_or_jid)
  end

  def lookup(%__MODULE__{}=rooms, xmpp_conn, [jid: jid]) do
    case Map.get(rooms.rooms, jid) do
      nil ->
        fetch_xmpp_room(rooms, jid, xmpp_conn)
      room ->
        {room, rooms}
    end
  end
  def lookup(%__MODULE__{}=rooms, _xmpp_conn, [name: name]) do
    case Map.get(rooms.rooms, name) do
      nil ->
        case fetch_api_room(rooms, name) do
          {:ok, room} ->
            rooms_rooms = rooms.rooms
                          |> Map.put(room.id, room)
                          |> Map.put(room.name, room)
            {room, %{rooms | rooms: rooms_rooms}}
          :error ->
            {nil, rooms}
        end
      room ->
        {room, rooms}
    end
  end

  def all(%__MODULE__{rooms: rooms}) do
    Map.values(rooms)
  end

  defp fetch_xmpp_room(rooms, room_jid, xmpp_conn) do
    id = "#{:erlang.system_time()}"
    xml = [{:xmlel, "query", [{"xmlns", "http://jabber.org/protocol/disco#info"}], []}]
    message = %Stanza.IQ{to: room_jid, type: "get", id: id, xml: xml}
    Connection.send(xmpp_conn, message)
    receive do
      {:stanza, %Stanza.IQ{id: ^id}=result} ->
        {:xmlel, "iq", _, [{:xmlel, "query", _, [{:xmlel, "identity", attrs, _}|_]}|_]} = result.xml
        room_name = :proplists.get_value("name", attrs, nil)
        room = %Cog.Chat.Room{id: room_jid, name: room_name, provider: "hipchat", is_dm: false}
        case fetch_api_room(rooms, room_name, room) do
          {:ok, room} ->
            rooms_rooms = rooms.rooms
            |> Map.put(room_jid, room)
            |> Map.put(room_name, room)
            {room, %{rooms | rooms: rooms_rooms}}
          :error ->
            {nil, rooms}
        end
      {:stanza, %Stanza.IQ{id: ^id, type: "error"}=error} ->
        Logger.error("Failed to retrieve room information for JID #{room_jid}: #{inspect error}")
        {nil, rooms}
    after @xmpp_timeout ->
        Logger.error("Room information request for JID #{room_jid} timed out")
        {nil, rooms}
    end
  end

  def fetch_api_room(rooms, name, room \\ nil) do
    url = Enum.join([rooms.hipchat_api_root, "room", name], "/") <> "?auth_token=#{rooms.api_token}"
    response = HTTPotion.get(url, headers: ["Accepts": "application/json"])
    case Poison.decode(response.body) do
      {:ok, result} ->
        if room == nil do
          {:ok, %Cog.Chat.Room{id: Map.get(result, "xmpp_jid"),
                               secondary_id: Map.get(result, "id"),
                               name: Map.get(result, "name"),
                               is_dm: false,
                               provider: "hipchat"}}
        else
          {:ok, %{room | secondary_id: Map.get(result, "id")}}
        end
      error ->
        Logger.error("Failed to retrieve details for room '#{name}' from HipChat's API: #{inspect error}")
        :error
    end
  end

end

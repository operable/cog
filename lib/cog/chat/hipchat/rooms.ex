defmodule Cog.Chat.HipChat.Rooms do

  require Logger

  alias Romeo.Connection
  alias Romeo.Stanza

  @xmpp_timeout 5000

  defstruct [:api_token, :hipchat_api_root, :rooms]

  def new(api_root, api_token) do
    %__MODULE__{api_token: api_token, hipchat_api_root: api_root, rooms: %{}}
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
          {nil, rooms} ->
            {nil, rooms}
          {room, rooms} ->
            rooms_rooms = rooms.rooms
                          |> Map.put(room.id, room)
                          |> Map.put(room.name, room)
            {room, %{rooms | rooms: rooms_rooms}}
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
        case result.xml do
        {:xmlel, "iq", _, [{:xmlel, "query", _, [{:xmlel, "identity", attrs, _}|_]}|_]} ->
            room_name = :proplists.get_value("name", attrs, nil)
            room = %Cog.Chat.Room{id: room_jid, name: room_name, provider: "hipchat", is_dm: false}
            case fetch_api_room(rooms, room_name, room) do
              nil ->
                {nil, rooms}
              room ->
                rooms_rooms = rooms.rooms
                |> Map.put(room_jid, room)
                |> Map.put(room_name, room)
                {room, %{rooms | rooms: rooms_rooms}}
            end
          {:xmlel, "iq", _, [{:xmlel, "query", _, _}, {:xmlel, "error", _, _}|_]} ->
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

  def fetch_api_room(rooms, name, room \\ nil)
  def fetch_api_room(rooms, name, nil) do
    name = URI.encode(name)
    url = Enum.join([rooms.hipchat_api_root, "room", name], "/") <> "?auth_token=#{rooms.api_token}"
    response = HTTPotion.get(url, headers: ["Accepts": "application/json"])
    case response.status_code do
      404 ->
        {nil, rooms}
      200 ->
        result = Poison.decode!(response.body)
        room = %Cog.Chat.Room{id: Map.get(result, "xmpp_jid"),
                              secondary_id: ensure_string(Map.get(result, "id")),
                              name: Map.get(result, "name"),
                              is_dm: false,
                              provider: "hipchat"}
        rooms_rooms = rooms.rooms
        |> Map.put(room.id, room)
        |> Map.put(room.secondary_id, room)
        {room, %{rooms | rooms: rooms_rooms}}
      _ ->
        Logger.error("Failed to lookup room '#{name}' via HipChat API: #{inspect response.body}")
        {nil, rooms}
    end
  end
  def fetch_api_room(rooms, name, room) do
    name = URI.encode(name)
    url = Enum.join([rooms.hipchat_api_root, "room", name], "/") <> "?auth_token=#{rooms.api_token}"
    response = HTTPotion.get(url, headers: ["Accepts": "application/json"])
    case response.status_code do
      404 ->
        Logger.warn("Unexpected 'not found' result retrieving room info from HipChat API for '#{name}'.")
        nil
      200 ->
        result = Poison.decode!(response.body)
        %{room | secondary_id: ensure_string(Map.get(result, "id"))}
      _ ->
        Logger.error("Failed to lookuproom '#{name}' via HipChat API: #{inspect response.body}")
        nil
    end
  end

  defp ensure_string(n) when is_integer(n), do: Integer.to_string(n)
  defp ensure_string(n) when is_binary(n), do: n
end

defimpl String.Chars, for: Cog.Chat.HipChat.Rooms do

  alias Cog.Chat.HipChat.Rooms

  def to_string(%Rooms{rooms: rooms}) do
    "<Cog.Chat.HipChat.Rooms[rooms: #{length(Map.values(rooms))}]>"
  end

end

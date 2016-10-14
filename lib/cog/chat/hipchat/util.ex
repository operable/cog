defmodule Cog.Chat.HipChat.Util do

  require Record

  Record.defrecord :xmlel, Record.extract(:xmlel, from_lib: "fast_xml/include/fxml.hrl")

  alias Romeo.Stanza
  alias Cog.Chat.User

  def classify_message(%Stanza.Message{}=message) do
    case check_invite(message) do
      {true, room_name} ->
        {:invite, room_name}
      false ->
        cond do
          message.type == "groupchat" ->
            case parse_jid(message.from.full) do
              nil ->
                :ignore
              {room_jid, name} ->
                {:groupchat, room_jid, name, message.body}
            end
          message.type == "chat" ->
            if message.body == nil or message.body == "" do
              :ignore
            else
              jid = parse_dm_jid(message.from.full)
              {:dm, jid, message.body}
            end
          true ->
            :ignore
        end
    end
  end

  def user_from_roster(item) do
    jid = item.jid.full
    [first_name, last_name] = case String.split(item.name, " ", parts: 2) do
                                [name] ->
                                  [name, ""]
                                names ->
                                  names
                              end
    {:xmlel, "item", attrs, _} = item.xml
    %User{id: jid,
          provider: "hipchat",
          email: :proplists.get_value("email", attrs, ""),
          first_name: first_name,
          last_name: last_name,
          mention_name: item.name,
          handle: :proplists.get_value("mention_name", attrs, "")}
  end

  defp check_invite(%Stanza.Message{}=msg) do
    check_invite(xmlel(msg.xml, :children))
  end
  defp check_invite([]), do: false
  defp check_invite([{:xmlel, "x", [{"xmlns", "http://hipchat.com/protocol/muc#room"}],
                 children}|_]) do
    case Enum.reduce_while(children, nil, &extract_room/2) do
      nil ->
        false
      room_name when is_binary(room_name) ->
        {true, room_name}
    end
  end
  defp check_invite([_|t]), do: check_invite(t)


  defp extract_room({:xmlel, "name", _, [xmlcdata: room_name]}, _) do
    {:halt, room_name}
  end
  defp extract_room(_, acc), do: {:cont, acc}

  defp parse_jid(jid) do
    case String.split(jid, "/", parts: 2) do
      [_] ->
        nil
      [jid, resource] ->
        {jid, resource}
    end
  end

  defp parse_dm_jid(jid) do
    jid
    |> String.split("/", parts: 2)
    |> List.first
  end
end

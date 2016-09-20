defmodule Cog.Chat.HipChat.Util do

  require Record

  Record.defrecord :xmlel, Record.extract(:xmlel, from_lib: "fast_xml/include/fxml.hrl")

  alias Romeo.Stanza

  def check_invite(%Stanza.Message{}=msg) do
    check_invite(xmlel(msg.xml, :children))
  end
  def check_invite([]), do: false
  def check_invite([{:xmlel, "x", [{"xmlns", "http://hipchat.com/protocol/muc#room"}],
                 children}|_]) do
    case Enum.reduce_while(children, nil, &extract_room/2) do
      nil ->
        false
      room_name when is_binary(room_name) ->
        {true, room_name}
    end
  end
  def check_invite([_|t]), do: check_invite(t)


  defp extract_room({:xmlel, "name", _, [xmlcdata: room_name]}, _) do
    {:halt, room_name}
  end
  defp extract_room(_, acc), do: {:cont, acc}

end

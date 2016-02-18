defmodule Cog.Adapters.Test.API do

  def lookup_room("@" <> _) do
    {:ok, %{id: 1, name: "direct"}}
  end
  def lookup_room("#" <> room) do
    {:ok, %{id: 1, name: room}}
  end
  def lookup_room(room_or_user) do
    {:ok, %{id: 1, name: room_or_user}}
  end

  def lookup_direct_room(_user_id) do
    {:ok, %{id: "channel1"}}
  end
end

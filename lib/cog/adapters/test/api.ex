defmodule Cog.Adapters.Test.API do

  def lookup_room("@" <> _, as_user: _) do
    {:ok, %{id: 1, name: "direct"}}
  end
  def lookup_room("#" <> room, as_user: _) do
    {:ok, %{id: 1, name: room}}
  end
  def lookup_room(room_or_user, as_user: _) do
    {:ok, %{id: 1, name: room_or_user}}
  end

  def lookup_direct_room(user_id: _, as_user: _) do
    {:ok, %{id: 1, name: "direct"}}
  end
end

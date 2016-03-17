defmodule Cog.Adapters.Test do
  use Cog.Adapter

  def send_message(_room, _message) do
    {:error, :not_implemented}
  end

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

  def room_writeable?(_opts) do
    true
  end

  def mention_name(name) do
    "@" <> name
  end

  def name() do
    "test"
  end

  def display_name() do
    "Test"
  end
end

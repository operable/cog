defmodule Cog.Adapters.Null do
  use Cog.Adapter

  def send_message(_room, _message) do
    {:error, :not_implemented}
  end

  def lookup_room([id: id]) do
    Cog.Chat.Room.from_map(%{"id" => id, "name" => "Test room",
                                "topic" => "Test topic"}, :test)
  end
  def lookup_room([name: name]) do
    Cog.Chat.Room.from_map(%{"id" => "R12345", "name" => name,
                                "topic" => "#{name} topic"}, :test)
  end

  def lookup_direct_room(_opts) do
    {:error, :not_implemented}
  end

  def room_writeable?(_opts) do
    true
  end

  def mention_name(name) do
    "@" <> name
  end

  def name() do
    "null"
  end

  def display_name() do
    "Null"
  end
end

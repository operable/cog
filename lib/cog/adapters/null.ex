defmodule Cog.Adapters.Null do

  @behaviour Cog.Adapter

  def describe_tree() do
    []
  end

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

  def service_name() do
    "Null"
  end

  def mention_name(name) do
    "@" <> name
  end
end

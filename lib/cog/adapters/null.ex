defmodule Cog.Adapters.Null do

  @behaviour Cog.Adapter

  def describe_tree() do
    []
  end

  def lookup_room([id: id]) do
    Cog.Chat.Room.from_map(%{"id" => id, "name" => "Test room",
                                "topic" => "Test topic"}, :test)
  end
  def lookup_room([name: name]) do
    Cog.Chat.Room.from_map(%{"id" => "R12345", "name" => name,
                                "topic" => "#{name} topic"}, :test)
  end

  def lookup_user([id: id]) do
    Cog.Chat.User.from_map(%{"id" => id, "name" => "testuser", "first_name" => "Testy",
                                "last_name" => "McTesterson", "email" => "testy@example.com"}, :test)
  end
  def lookup_user([name: name]) do
    Cog.Chat.User.from_map(%{"id" => "U12345", "name" => name, "first_name" => "Testy",
                                "last_name" => "McTesterson", "email" => "testy@example.com"}, :test)
  end

  def direct_message(_id, _message) do
    {:error, :not_implemented}
  end

  def message(_room, _message) do
    {:error, :not_implemented}
  end

end

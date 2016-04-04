defmodule Cog.Adapters.Null do
  use Cog.Adapter

  def send_message(_room, _message) do
    {:error, :not_implemented}
  end

  def lookup_room(name) do
    {:ok, %{id: "R12345",
            name: name,
            topic: "#{name} topic"}}
  end

  def lookup_direct_room(_opts) do
    {:error, :not_implemented}
  end

  def room_writeable?(_opts) do
    true
  end

  def lookup_user("admininator") do
    {:ok, %{id: "admininator", handle: "admininator"}}
  end

  def lookup_user(_opts) do
    {:error, :not_implemented}
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

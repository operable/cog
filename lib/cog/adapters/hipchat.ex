defmodule Cog.Adapters.HipChat do
  use Cog.Adapter
  alias Cog.Adapters.HipChat

  def send_message(room, message) do
    HipChat.API.send_message(room, message)
  end

  def lookup_room(opts) do
    HipChat.API.lookup_room(opts)
  end

  def lookup_direct_room(opts) do
    HipChat.API.lookup_direct_room(opts)
  end

  # TODO: Research a real implementation
  def room_writeable?(_opts) do
    true
  end

  def mention_name(name) do
    "@" <> name
  end

  def name() do
    "hipchat"
  end

  def display_name() do
    "HipChat"
  end
end

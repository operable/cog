defmodule Cog.Adapters.IRC do
  use Cog.Adapter
  alias Cog.Adapters.IRC

  def send_message(room, message) do
    IRC.Connection.send_message(room, message)
  end

  def lookup_room(opts) do
    IRC.Connection.lookup_room(opts)
  end

  def lookup_direct_room(opts) do
    IRC.Connection.lookup_direct_room(opts)
  end

  # TODO: Research a real implementation
  def room_writeable?(_opts) do
    true
  end

  def mention_name(name) do
    name
  end

  def name() do
    "irc"
  end

  def display_name() do
    "IRC"
  end
end

defmodule Cog.Adapters.Slack do
  use Cog.Adapter
  alias Cog.Adapters.Slack.API

  def send_message(room, message) do
    with {:ok, room} <- lookup_room(room) do
      API.send_message(room.id, message)
    end
  end

  def lookup_room(opts) do
    API.lookup_room(opts)
  end

  def lookup_direct_room(opts) do
    API.lookup_direct_room(opts)
  end

  def mention_name(name) do
    "@" <> name
  end

  def name() do
    "slack"
  end

  def display_name() do
    "Slack"
  end
end

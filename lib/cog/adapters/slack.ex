defmodule Cog.Adapters.Slack do
  use Cog.Adapter
  alias Cog.Adapters.Slack

  def send_message(room, message) do
    Slack.API.send_message(room, message)
  end

  def lookup_room(opts) do
    Slack.API.lookup_room(opts)
  end

  def lookup_direct_room(opts) do
    Slack.API.lookup_direct_room(opts)
  end

  def room_writeable?(opts) do
    case lookup_room(opts) do
      {:ok, %{is_member: is_member}} ->
        is_member
      _ ->
        true
    end
  end

  def lookup_user(opts) do
    Slack.API.lookup_user(opts)
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

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
      {:ok, room} ->
        case Slack.RTMConnector.assigned_userid() do
          {:ok, userid} ->
            is_member?(room, userid)
          error ->
            error
        end
      error ->
        error
    end
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

  defp is_member?(%{members: members}, userid),
    do: Enum.member?(members, userid)
  defp is_member?(_room, _userid), do: true
end

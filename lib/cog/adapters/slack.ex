defmodule Cog.Adapters.Slack do

  import Supervisor.Spec
  @behaviour Cog.Adapter

  def describe_tree() do
    [supervisor(Cog.Adapters.Slack.Sup, [])]
  end

  def lookup_room([id: _id]=opts) do
    Cog.Adapters.Slack.API.lookup_room(opts)
  end
  def lookup_room([name: _name]=opts) do
    Cog.Adapters.Slack.API.lookup_room(opts)
  end

  def lookup_user([id: _id]=opts) do
    Cog.Adapters.Slack.API.lookup_user(opts)
  end
  def lookup_user([name: _name]=opts) do
    Cog.Adapters.Slack.API.lookup_user(opts)
  end

  def message(room, message) do
    case Cog.Adapters.Slack.API.lookup_room(room) do
      {:ok, room} ->
        Cog.Adapters.Slack.API.send_message(room.id, message)
      error ->
        error
    end
  end

end

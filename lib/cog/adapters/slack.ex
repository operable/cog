defmodule Cog.Adapters.Slack do
  use GenServer
  import Supervisor.Spec
  alias Cog.Adapters.Slack
  alias Cog.Adapters.Connector

  @behaviour Cog.Adapter

  def describe_tree() do
    [supervisor(Slack.Sup, []),
     worker(Connector, [Cog.Adapters.Slack])]
  end

  def send_message(room, message) do
    with {:ok, room} <- lookup_room(room) do
      Slack.API.send_message(room.id, message)
    end
  end

  def lookup_room(opts) do
    Slack.API.lookup_room(opts)
  end

  def lookup_direct_room(opts) do
    Slack.API.lookup_direct_room(opts)
  end

  def service_name() do
    "Slack"
  end

  def bus_name() do
    "slack"
  end

  def mention_name(name) do
    "@" <> name
  end
end

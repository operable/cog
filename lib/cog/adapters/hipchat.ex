defmodule Cog.Adapters.HipChat do
  import Supervisor.Spec, only: [supervisor: 2]
  alias Cog.Adapters.HipChat

  @behaviour Cog.Adapter

  def describe_tree() do
    [supervisor(Cog.Adapters.HipChat.Supervisor, [])]
  end

  def send_message(room, message) do
    HipChat.API.send_message(room, message)
  end

  def lookup_room(opts) do
    HipChat.API.lookup_room(opts)
  end

  def lookup_direct_room(opts) do
    HipChat.API.lookup_direct_room(opts)
  end

  def service_name() do
    "HipChat"
  end

  def bus_name() do
    "hipchat"
  end

  def mention_name(name) do
    "@" <> name
  end
end

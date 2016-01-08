defmodule Cog.Adapters.WebSocket do
  import Supervisor.Spec
  alias Cog.Adapters.WebSocket

  @behaviour Cog.Adapter

  def describe_tree do
    [supervisor(WebSocket.Sup, [])]
  end

  def lookup_room(_) do
    raise "Not implemented"
  end

  def lookup_user(_) do
    raise "Not implemented"
  end

  def message(_room, message) do
    WebSocket.Server.message(message)
  end
end

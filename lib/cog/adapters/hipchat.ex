defmodule Cog.Adapters.HipChat do
  require Logger

  import Supervisor.Spec, only: [supervisor: 2]

  alias Cog.Adapters.HipChat

  @behaviour Cog.Adapter

  def describe_tree() do
    [supervisor(Cog.Adapters.HipChat.Supervisor, [])]
  end

  def lookup_user(opts), do: HipChat.API.lookup_user(opts)
  def lookup_room(opts), do: HipChat.API.lookup_room(opts)
  def message(room, message), do: HipChat.API.send_message(room, message)

end

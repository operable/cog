defmodule Cog.Adapters.HipChat.Supervisor do
  use Supervisor
  alias Cog.Adapters.HipChat

  def start_link() do
    Supervisor.start_link(__MODULE__, [])
  end

  def init(_) do
    children = [worker(HipChat, []),
                worker(HipChat.Connection, [])]

    supervise(children, strategy: :one_for_all)
  end
end
